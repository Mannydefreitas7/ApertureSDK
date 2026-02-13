//
//  PluginSystem.swift
//  VideoEditor
//
//  插件系统模块 - 插件架构、自定义滤镜、LUT导入、脚本
//

import Foundation
import CoreImage
import AVFoundation
import JavaScriptCore
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 插件协议

/// 插件类型
enum PluginType: String, Codable, CaseIterable {
    case effect = "效果"
    case filter = "滤镜"
    case transition = "转场"
    case generator = "生成器"
    case audio = "音频"
    case export = "导出"
    case import_ = "导入"
    case utility = "工具"
    case ai = "AI"
}

/// 插件信息
struct PluginInfo: Codable, Identifiable {
    let id: String
    var name: String
    var version: String
    var author: String
    var description: String
    var type: PluginType
    var category: String
    var icon: String?
    var website: String?
    var license: String
    var minAppVersion: String
    var dependencies: [String]
    var keywords: [String]
}

/// 插件参数
struct PluginParameter: Codable, Identifiable {
    let id: String
    var name: String
    var displayName: String
    var type: ParameterType
    var defaultValue: AnyCodable
    var minValue: AnyCodable?
    var maxValue: AnyCodable?
    var options: [ParameterOption]?
    var group: String?
    var isAdvanced: Bool

    enum ParameterType: String, Codable {
        case float = "float"
        case int = "int"
        case bool = "bool"
        case string = "string"
        case color = "color"
        case point = "point"
        case rect = "rect"
        case image = "image"
        case selection = "selection"
        case file = "file"
        case angle = "angle"
        case curve = "curve"
    }

    struct ParameterOption: Codable {
        var label: String
        var value: AnyCodable
    }
}

/// 可编码的任意类型
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intVal as Int:
            try container.encode(intVal)
        case let doubleVal as Double:
            try container.encode(doubleVal)
        case let boolVal as Bool:
            try container.encode(boolVal)
        case let stringVal as String:
            try container.encode(stringVal)
        case let arrayVal as [Any]:
            try container.encode(arrayVal.map { AnyCodable($0) })
        case let dictVal as [String: Any]:
            try container.encode(dictVal.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

/// 插件接口协议
protocol PluginInterface {
    var info: PluginInfo { get }
    var parameters: [PluginParameter] { get }

    func initialize() throws
    func uninitialize()
    func process(input: PluginInput, parameters: [String: Any]) -> PluginOutput?
}

/// 插件输入
struct PluginInput {
    var image: CIImage?
    var pixelBuffer: CVPixelBuffer?
    var audioBuffer: AVAudioPCMBuffer?
    var metadata: [String: Any]
    var time: CMTime
    var duration: CMTime
}

/// 插件输出
struct PluginOutput {
    var image: CIImage?
    var pixelBuffer: CVPixelBuffer?
    var audioBuffer: AVAudioPCMBuffer?
    var metadata: [String: Any]
}

// MARK: - 插件管理器

/// 插件管理器
class PluginManager: ObservableObject {
    static let shared = PluginManager()

    @Published var installedPlugins: [PluginInfo] = []
    @Published var enabledPlugins: Set<String> = []
    @Published var pluginErrors: [String: Error] = [:]

    private var loadedPlugins: [String: PluginInterface] = [:]
    private var pluginBundles: [String: Bundle] = [:]

    private let pluginsDirectory: URL
    private let userPluginsDirectory: URL

    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = appSupport.appendingPathComponent("VideoEditor")

        pluginsDirectory = Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns")
        userPluginsDirectory = appDir.appendingPathComponent("Plugins")

        try? fileManager.createDirectory(at: userPluginsDirectory, withIntermediateDirectories: true)

        loadPlugins()
    }

    /// 加载所有插件
    func loadPlugins() {
        // 加载内置插件
        loadPluginsFromDirectory(pluginsDirectory)

        // 加载用户插件
        loadPluginsFromDirectory(userPluginsDirectory)

        // 加载启用状态
        if let enabledData = UserDefaults.standard.data(forKey: "enabled_plugins"),
           let enabled = try? JSONDecoder().decode(Set<String>.self, from: enabledData) {
            enabledPlugins = enabled
        }
    }

    private func loadPluginsFromDirectory(_ directory: URL) {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }

        for url in contents {
            if url.pathExtension == "veplugin" {
                loadPlugin(from: url)
            } else if url.pathExtension == "js" {
                loadJavaScriptPlugin(from: url)
            }
        }
    }

    /// 加载插件
    private func loadPlugin(from url: URL) {
        // 加载插件Bundle
        guard let bundle = Bundle(url: url) else { return }

        // 读取Info.plist
        guard let infoURL = bundle.url(forResource: "Info", withExtension: "plist"),
              let infoData = try? Data(contentsOf: infoURL),
              let info = try? PropertyListDecoder().decode(PluginInfo.self, from: infoData) else {
            return
        }

        installedPlugins.append(info)
        pluginBundles[info.id] = bundle
    }

    /// 加载JavaScript插件
    private func loadJavaScriptPlugin(from url: URL) {
        guard let script = try? String(contentsOf: url, encoding: .utf8) else { return }

        let jsPlugin = JavaScriptPlugin(scriptURL: url, script: script)

        let info = jsPlugin.info
        installedPlugins.append(info)
        loadedPlugins[info.id] = jsPlugin
    }

    /// 安装插件
    func installPlugin(from url: URL) throws {
        let fileManager = FileManager.default
        let fileName = url.lastPathComponent
        let destinationURL = userPluginsDirectory.appendingPathComponent(fileName)

        // 如果已存在，先删除
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        // 复制插件
        try fileManager.copyItem(at: url, to: destinationURL)

        // 重新加载
        loadPlugin(from: destinationURL)
    }

    /// 卸载插件
    func uninstallPlugin(_ pluginId: String) throws {
        // 禁用插件
        disablePlugin(pluginId)

        // 从列表移除
        installedPlugins.removeAll { $0.id == pluginId }

        // 删除文件
        if let bundle = pluginBundles[pluginId] {
            try FileManager.default.removeItem(at: bundle.bundleURL)
            pluginBundles.removeValue(forKey: pluginId)
        }

        loadedPlugins.removeValue(forKey: pluginId)
    }

    /// 启用插件
    func enablePlugin(_ pluginId: String) {
        enabledPlugins.insert(pluginId)
        saveEnabledPlugins()

        // 初始化插件
        if let plugin = loadedPlugins[pluginId] {
            try? plugin.initialize()
        }
    }

    /// 禁用插件
    func disablePlugin(_ pluginId: String) {
        enabledPlugins.remove(pluginId)
        saveEnabledPlugins()

        // 反初始化插件
        loadedPlugins[pluginId]?.uninitialize()
    }

    /// 获取插件实例
    func getPlugin(_ pluginId: String) -> PluginInterface? {
        guard enabledPlugins.contains(pluginId) else { return nil }
        return loadedPlugins[pluginId]
    }

    /// 获取指定类型的插件
    func getPlugins(ofType type: PluginType) -> [PluginInfo] {
        return installedPlugins.filter { $0.type == type && enabledPlugins.contains($0.id) }
    }

    private func saveEnabledPlugins() {
        if let data = try? JSONEncoder().encode(enabledPlugins) {
            UserDefaults.standard.set(data, forKey: "enabled_plugins")
        }
    }
}

// MARK: - JavaScript插件

/// JavaScript插件
class JavaScriptPlugin: PluginInterface {
    let scriptURL: URL
    let script: String

    private var context: JSContext?
    private var _info: PluginInfo?
    private var _parameters: [PluginParameter] = []

    var info: PluginInfo {
        return _info ?? PluginInfo(
            id: scriptURL.deletingPathExtension().lastPathComponent,
            name: "Unknown",
            version: "1.0.0",
            author: "Unknown",
            description: "",
            type: .effect,
            category: "General",
            license: "MIT",
            minAppVersion: "1.0.0",
            dependencies: [],
            keywords: []
        )
    }

    var parameters: [PluginParameter] {
        return _parameters
    }

    init(scriptURL: URL, script: String) {
        self.scriptURL = scriptURL
        self.script = script

        setupContext()
        parsePluginInfo()
    }

    private func setupContext() {
        context = JSContext()

        // 异常处理
        context?.exceptionHandler = { context, exception in
            print("JavaScript Error: \(exception?.toString() ?? "unknown")")
        }

        // 注入API
        injectAPI()

        // 执行脚本
        context?.evaluateScript(script)
    }

    private func injectAPI() {
        guard let context = context else { return }

        // 控制台日志
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("[Plugin] \(message)")
        }
        context.setObject(consoleLog, forKeyedSubscript: "log" as NSString)

        // 数学函数
        let sinFunc: @convention(block) (Double) -> Double = { Foundation.sin($0) }
        let cosFunc: @convention(block) (Double) -> Double = { Foundation.cos($0) }
        let sqrtFunc: @convention(block) (Double) -> Double = { Foundation.sqrt($0) }
        context.setObject(sinFunc, forKeyedSubscript: "sin" as NSString)
        context.setObject(cosFunc, forKeyedSubscript: "cos" as NSString)
        context.setObject(sqrtFunc, forKeyedSubscript: "sqrt" as NSString)

        // 颜色处理
        let rgbToHsl: @convention(block) (Double, Double, Double) -> [Double] = { r, g, b in
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let l = (maxC + minC) / 2

            if maxC == minC {
                return [0, 0, l]
            }

            let d = maxC - minC
            let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)

            var h: Double = 0
            if maxC == r {
                h = (g - b) / d + (g < b ? 6 : 0)
            } else if maxC == g {
                h = (b - r) / d + 2
            } else {
                h = (r - g) / d + 4
            }
            h /= 6

            return [h, s, l]
        }
        context.setObject(rgbToHsl, forKeyedSubscript: "rgbToHsl" as NSString)
    }

    private func parsePluginInfo() {
        guard let context = context else { return }

        // 获取插件信息
        if let infoObj = context.objectForKeyedSubscript("pluginInfo"),
           !infoObj.isUndefined {
            _info = PluginInfo(
                id: infoObj.objectForKeyedSubscript("id")?.toString() ?? UUID().uuidString,
                name: infoObj.objectForKeyedSubscript("name")?.toString() ?? "Unnamed",
                version: infoObj.objectForKeyedSubscript("version")?.toString() ?? "1.0.0",
                author: infoObj.objectForKeyedSubscript("author")?.toString() ?? "Unknown",
                description: infoObj.objectForKeyedSubscript("description")?.toString() ?? "",
                type: PluginType(rawValue: infoObj.objectForKeyedSubscript("type")?.toString() ?? "effect") ?? .effect,
                category: infoObj.objectForKeyedSubscript("category")?.toString() ?? "General",
                license: infoObj.objectForKeyedSubscript("license")?.toString() ?? "MIT",
                minAppVersion: infoObj.objectForKeyedSubscript("minAppVersion")?.toString() ?? "1.0.0",
                dependencies: [],
                keywords: []
            )
        }

        // 获取参数
        if let paramsArray = context.objectForKeyedSubscript("parameters")?.toArray() as? [[String: Any]] {
            for paramDict in paramsArray {
                if let param = parseParameter(paramDict) {
                    _parameters.append(param)
                }
            }
        }
    }

    private func parseParameter(_ dict: [String: Any]) -> PluginParameter? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let typeString = dict["type"] as? String,
              let type = PluginParameter.ParameterType(rawValue: typeString) else {
            return nil
        }

        return PluginParameter(
            id: id,
            name: id,
            displayName: name,
            type: type,
            defaultValue: AnyCodable(dict["default"] ?? 0),
            minValue: dict["min"] != nil ? AnyCodable(dict["min"]!) : nil,
            maxValue: dict["max"] != nil ? AnyCodable(dict["max"]!) : nil,
            options: nil,
            group: dict["group"] as? String,
            isAdvanced: dict["advanced"] as? Bool ?? false
        )
    }

    func initialize() throws {
        context?.objectForKeyedSubscript("initialize")?.call(withArguments: [])
    }

    func uninitialize() {
        context?.objectForKeyedSubscript("uninitialize")?.call(withArguments: [])
    }

    func process(input: PluginInput, parameters: [String: Any]) -> PluginOutput? {
        guard let context = context,
              let processFunc = context.objectForKeyedSubscript("process"),
              !processFunc.isUndefined else {
            return nil
        }

        // 转换输入
        let inputDict: [String: Any] = [
            "time": input.time.seconds,
            "duration": input.duration.seconds,
            "metadata": input.metadata
        ]

        // 调用处理函数
        if let result = processFunc.call(withArguments: [inputDict, parameters]) {
            // 解析输出
            // 这里需要处理图像数据的转换
            return PluginOutput(image: input.image, metadata: [:])
        }

        return nil
    }
}

// MARK: - LUT管理器

/// LUT信息
struct LUTInfo: Identifiable, Codable {
    let id: UUID
    var name: String
    var filename: String
    var size: Int // 通常是17, 32, 64
    var category: String
    var author: String?
    var thumbnail: URL?
    var isBuiltIn: Bool
    var isFavorite: Bool
    var usageCount: Int
}

/// LUT管理器
class LUTManager: ObservableObject {
    static let shared = LUTManager()

    @Published var luts: [LUTInfo] = []
    @Published var categories: [String] = []
    @Published var recentLUTs: [LUTInfo] = []

    private var lutFilters: [UUID: CIFilter] = [:]
    private let lutsDirectory: URL

    init() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        lutsDirectory = documentsURL.appendingPathComponent("LUTs")

        try? fileManager.createDirectory(at: lutsDirectory, withIntermediateDirectories: true)

        loadLUTs()
        loadBuiltInLUTs()
    }

    /// 加载LUTs
    private func loadLUTs() {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(at: lutsDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for url in contents {
            let ext = url.pathExtension.lowercased()
            if ext == "cube" || ext == "3dl" || ext == "look" {
                if let lut = parseLUT(from: url) {
                    luts.append(lut)
                }
            }
        }

        updateCategories()
    }

    /// 加载内置LUTs
    private func loadBuiltInLUTs() {
        let builtInCategories = [
            ("电影感", ["Cinematic Warm", "Cinematic Cool", "Blockbuster", "Film Noir"]),
            ("复古", ["Vintage 60s", "Vintage 70s", "Polaroid", "Faded Film"]),
            ("黑白", ["Classic B&W", "High Contrast B&W", "Noir"]),
            ("鲜艳", ["Vivid Colors", "Pop Art", "Neon"]),
            ("情绪", ["Moody Blue", "Orange Teal", "Autumn"])
        ]

        for (category, names) in builtInCategories {
            for name in names {
                let lut = LUTInfo(
                    id: UUID(),
                    name: name,
                    filename: "\(name).cube",
                    size: 33,
                    category: category,
                    isBuiltIn: true,
                    isFavorite: false,
                    usageCount: 0
                )
                luts.append(lut)
            }
        }

        updateCategories()
    }

    private func updateCategories() {
        categories = Array(Set(luts.map { $0.category })).sorted()
    }

    /// 解析LUT文件
    private func parseLUT(from url: URL) -> LUTInfo? {
        let name = url.deletingPathExtension().lastPathComponent

        // 解析.cube文件获取尺寸
        var size = 33

        if let content = try? String(contentsOf: url, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("LUT_3D_SIZE") {
                    let parts = line.components(separatedBy: .whitespaces)
                    if parts.count >= 2, let s = Int(parts[1]) {
                        size = s
                        break
                    }
                }
            }
        }

        return LUTInfo(
            id: UUID(),
            name: name,
            filename: url.lastPathComponent,
            size: size,
            category: "用户",
            isBuiltIn: false,
            isFavorite: false,
            usageCount: 0
        )
    }

    /// 导入LUT
    func importLUT(from url: URL) throws -> LUTInfo {
        let fileManager = FileManager.default
        let destinationURL = lutsDirectory.appendingPathComponent(url.lastPathComponent)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: url, to: destinationURL)

        guard let lut = parseLUT(from: destinationURL) else {
            throw NSError(domain: "LUTError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析LUT文件"])
        }

        luts.append(lut)
        updateCategories()

        return lut
    }

    /// 删除LUT
    func deleteLUT(_ lut: LUTInfo) throws {
        guard !lut.isBuiltIn else {
            throw NSError(domain: "LUTError", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法删除内置LUT"])
        }

        let fileURL = lutsDirectory.appendingPathComponent(lut.filename)
        try FileManager.default.removeItem(at: fileURL)

        luts.removeAll { $0.id == lut.id }
        lutFilters.removeValue(forKey: lut.id)
    }

    /// 应用LUT
    func applyLUT(_ lut: LUTInfo, to image: CIImage, intensity: Float = 1.0) -> CIImage? {
        guard let filter = getLUTFilter(lut) else { return image }

        filter.setValue(image, forKey: kCIInputImageKey)

        guard let outputImage = filter.outputImage else { return image }

        // 混合原图和LUT效果
        if intensity < 1.0 {
            guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return outputImage }
            blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
            blendFilter.setValue(outputImage, forKey: kCIInputImageKey)

            // 创建灰度遮罩
            let maskColor = CIColor(red: CGFloat(intensity), green: CGFloat(intensity), blue: CGFloat(intensity))
            let maskImage = CIImage(color: maskColor).cropped(to: image.extent)
            blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)

            return blendFilter.outputImage
        }

        return outputImage
    }

    private func getLUTFilter(_ lut: LUTInfo) -> CIFilter? {
        if let cached = lutFilters[lut.id] {
            return cached
        }

        let lutURL: URL
        if lut.isBuiltIn {
            // 内置LUT - 生成默认的颜色立方体
            return createDefaultLUTFilter(for: lut)
        } else {
            lutURL = lutsDirectory.appendingPathComponent(lut.filename)
        }

        guard let filter = createLUTFilter(from: lutURL, size: lut.size) else {
            return nil
        }

        lutFilters[lut.id] = filter
        return filter
    }

    private func createLUTFilter(from url: URL, size: Int) -> CIFilter? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var cubeData = [Float]()
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 跳过注释和元数据
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("TITLE") ||
               trimmed.hasPrefix("LUT_") || trimmed.hasPrefix("DOMAIN_") {
                continue
            }

            let values = trimmed.components(separatedBy: .whitespaces).compactMap { Float($0) }
            if values.count >= 3 {
                cubeData.append(contentsOf: [values[0], values[1], values[2], 1.0])
            }
        }

        let expectedCount = size * size * size * 4
        guard cubeData.count == expectedCount else {
            return nil
        }

        let data = Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size)

        guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else { return nil }
        filter.setValue(size, forKey: "inputCubeDimension")
        filter.setValue(data, forKey: "inputCubeData")
        filter.setValue(CGColorSpace(name: CGColorSpace.sRGB), forKey: "inputColorSpace")

        return filter
    }

    private func createDefaultLUTFilter(for lut: LUTInfo) -> CIFilter? {
        // 创建简单的颜色调整滤镜作为默认LUT
        switch lut.name {
        case "Cinematic Warm":
            return CIFilter(name: "CITemperatureAndTint", parameters: [
                "inputTargetNeutral": CIVector(x: 6500, y: 0),
                "inputNeutral": CIVector(x: 5500, y: 0)
            ])
        case "Classic B&W":
            return CIFilter(name: "CIPhotoEffectMono")
        case "Vintage 70s":
            return CIFilter(name: "CIPhotoEffectInstant")
        default:
            return nil
        }
    }

    /// 切换收藏
    func toggleFavorite(_ lut: LUTInfo) {
        if let index = luts.firstIndex(where: { $0.id == lut.id }) {
            luts[index].isFavorite.toggle()
        }
    }

    /// 更新使用次数
    func incrementUsage(_ lut: LUTInfo) {
        if let index = luts.firstIndex(where: { $0.id == lut.id }) {
            luts[index].usageCount += 1

            // 更新最近使用
            recentLUTs.removeAll { $0.id == lut.id }
            recentLUTs.insert(luts[index], at: 0)
            if recentLUTs.count > 10 {
                recentLUTs = Array(recentLUTs.prefix(10))
            }
        }
    }
}

// MARK: - 自定义滤镜

/// 自定义滤镜类型
enum CustomFilterType: String, CaseIterable {
    case ciKernel = "CIKernel"
    case metalShader = "Metal Shader"
    case compositeFilter = "复合滤镜"
    case colorMatrix = "颜色矩阵"
}

/// 自定义滤镜
class CustomFilter: Identifiable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var type: CustomFilterType
    @Published var kernelSource: String
    @Published var parameters: [PluginParameter]
    @Published var isEnabled: Bool = true

    private var compiledKernel: CIKernel?
    private var colorKernel: CIColorKernel?
    private var warpKernel: CIWarpKernel?

    init(name: String, type: CustomFilterType, kernelSource: String = "") {
        self.id = UUID()
        self.name = name
        self.type = type
        self.kernelSource = kernelSource
        self.parameters = []

        if !kernelSource.isEmpty {
            compileKernel()
        }
    }

    /// 编译内核
    func compileKernel() {
        guard !kernelSource.isEmpty else { return }

        do {
            // 尝试编译为颜色内核
            if let colorKernel = try? CIColorKernel(source: kernelSource) {
                self.colorKernel = colorKernel
                return
            }

            // 尝试编译为扭曲内核
            if let warpKernel = try? CIWarpKernel(source: kernelSource) {
                self.warpKernel = warpKernel
                return
            }

            // 尝试编译为通用内核
            if let kernel = try? CIKernel(source: kernelSource) {
                self.compiledKernel = kernel
            }
        } catch {
            print("Kernel compilation error: \(error)")
        }
    }

    /// 应用滤镜
    func apply(to image: CIImage, parameters: [String: Any] = [:]) -> CIImage? {
        guard isEnabled else { return image }

        switch type {
        case .ciKernel:
            return applyKernel(to: image, parameters: parameters)
        case .metalShader:
            return applyMetalShader(to: image, parameters: parameters)
        case .compositeFilter:
            return applyCompositeFilter(to: image, parameters: parameters)
        case .colorMatrix:
            return applyColorMatrix(to: image, parameters: parameters)
        }
    }

    private func applyKernel(to image: CIImage, parameters: [String: Any]) -> CIImage? {
        if let colorKernel = colorKernel {
            return colorKernel.apply(extent: image.extent, arguments: [image])
        }

        if let warpKernel = warpKernel {
            return warpKernel.apply(extent: image.extent, roiCallback: { _, rect in rect }, image: image, arguments: [])
        }

        if let kernel = compiledKernel {
            return kernel.apply(extent: image.extent, roiCallback: { _, rect in rect }, arguments: [image])
        }

        return image
    }

    private func applyMetalShader(to image: CIImage, parameters: [String: Any]) -> CIImage? {
        // Metal着色器需要通过MetalRenderEngine处理
        return image
    }

    private func applyCompositeFilter(to image: CIImage, parameters: [String: Any]) -> CIImage? {
        // 复合滤镜 - 组合多个CIFilter
        return image
    }

    private func applyColorMatrix(to image: CIImage, parameters: [String: Any]) -> CIImage? {
        guard let matrix = parameters["matrix"] as? [Float], matrix.count >= 20 else {
            return image
        }

        let filter = CIFilter(name: "CIColorMatrix")
        filter?.setValue(image, forKey: kCIInputImageKey)

        filter?.setValue(CIVector(x: CGFloat(matrix[0]), y: CGFloat(matrix[1]), z: CGFloat(matrix[2]), w: CGFloat(matrix[3])), forKey: "inputRVector")
        filter?.setValue(CIVector(x: CGFloat(matrix[4]), y: CGFloat(matrix[5]), z: CGFloat(matrix[6]), w: CGFloat(matrix[7])), forKey: "inputGVector")
        filter?.setValue(CIVector(x: CGFloat(matrix[8]), y: CGFloat(matrix[9]), z: CGFloat(matrix[10]), w: CGFloat(matrix[11])), forKey: "inputBVector")
        filter?.setValue(CIVector(x: CGFloat(matrix[12]), y: CGFloat(matrix[13]), z: CGFloat(matrix[14]), w: CGFloat(matrix[15])), forKey: "inputAVector")
        filter?.setValue(CIVector(x: CGFloat(matrix[16]), y: CGFloat(matrix[17]), z: CGFloat(matrix[18]), w: CGFloat(matrix[19])), forKey: "inputBiasVector")

        return filter?.outputImage
    }
}

/// 自定义滤镜管理器
class CustomFilterManager: ObservableObject {
    static let shared = CustomFilterManager()

    @Published var filters: [CustomFilter] = []

    init() {
        loadFilters()
        createDefaultFilters()
    }

    private func loadFilters() {
        // 从本地加载保存的自定义滤镜
    }

    private func createDefaultFilters() {
        // 创建一些默认的自定义滤镜示例

        // 反相滤镜
        let invertFilter = CustomFilter(name: "反相", type: .ciKernel, kernelSource: """
            kernel vec4 invertColor(__sample s) {
                return vec4(1.0 - s.r, 1.0 - s.g, 1.0 - s.b, s.a);
            }
            """)
        filters.append(invertFilter)

        // 怀旧滤镜
        let sepiaMatrix: [Float] = [
            0.393, 0.769, 0.189, 0,
            0.349, 0.686, 0.168, 0,
            0.272, 0.534, 0.131, 0,
            0, 0, 0, 1,
            0, 0, 0, 0
        ]
        let sepiaFilter = CustomFilter(name: "怀旧", type: .colorMatrix)
        sepiaFilter.parameters = [
            PluginParameter(id: "matrix", name: "matrix", displayName: "矩阵", type: .string, defaultValue: AnyCodable(sepiaMatrix), group: nil, isAdvanced: false)
        ]
        filters.append(sepiaFilter)
    }

    /// 创建滤镜
    func createFilter(name: String, type: CustomFilterType, kernelSource: String = "") -> CustomFilter {
        let filter = CustomFilter(name: name, type: type, kernelSource: kernelSource)
        filters.append(filter)
        saveFilters()
        return filter
    }

    /// 删除滤镜
    func deleteFilter(_ filter: CustomFilter) {
        filters.removeAll { $0.id == filter.id }
        saveFilters()
    }

    /// 复制滤镜
    func duplicateFilter(_ filter: CustomFilter) -> CustomFilter {
        let copy = CustomFilter(name: "\(filter.name) 副本", type: filter.type, kernelSource: filter.kernelSource)
        copy.parameters = filter.parameters
        filters.append(copy)
        saveFilters()
        return copy
    }

    private func saveFilters() {
        // 保存到本地
    }
}

// MARK: - 脚本引擎

/// 脚本类型
enum ScriptType: String, CaseIterable {
    case javascript = "JavaScript"
    case python = "Python"
    case lua = "Lua"
}

/// 脚本
class Script: Identifiable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var type: ScriptType
    @Published var source: String
    @Published var isEnabled: Bool = true
    @Published var lastRunTime: Date?
    @Published var lastError: String?

    private var jsContext: JSContext?

    init(name: String, type: ScriptType, source: String = "") {
        self.id = UUID()
        self.name = name
        self.type = type
        self.source = source
    }

    /// 执行脚本
    func execute(input: [String: Any] = [:]) -> [String: Any]? {
        lastRunTime = Date()
        lastError = nil

        switch type {
        case .javascript:
            return executeJavaScript(input: input)
        case .python:
            lastError = "Python脚本暂不支持"
            return nil
        case .lua:
            lastError = "Lua脚本暂不支持"
            return nil
        }
    }

    private func executeJavaScript(input: [String: Any]) -> [String: Any]? {
        let context = JSContext()!

        // 异常处理
        context.exceptionHandler = { [weak self] _, exception in
            self?.lastError = exception?.toString()
        }

        // 注入输入
        context.setObject(input, forKeyedSubscript: "input" as NSString)

        // 注入API
        injectScriptAPI(context)

        // 执行脚本
        context.evaluateScript(source)

        // 获取输出
        if let output = context.objectForKeyedSubscript("output")?.toDictionary() as? [String: Any] {
            return output
        }

        return nil
    }

    private func injectScriptAPI(_ context: JSContext) {
        // 日志
        let log: @convention(block) (String) -> Void = { message in
            print("[Script] \(message)")
        }
        context.setObject(log, forKeyedSubscript: "log" as NSString)

        // 项目API
        let getProjectInfo: @convention(block) () -> [String: Any] = {
            return ["name": "Project", "duration": 60.0]
        }
        context.setObject(getProjectInfo, forKeyedSubscript: "getProjectInfo" as NSString)

        // 时间线API
        let getClips: @convention(block) () -> [[String: Any]] = {
            return []
        }
        context.setObject(getClips, forKeyedSubscript: "getClips" as NSString)

        // 效果API
        let applyEffect: @convention(block) (String, String, [String: Any]) -> Bool = { clipId, effectId, parameters in
            return true
        }
        context.setObject(applyEffect, forKeyedSubscript: "applyEffect" as NSString)
    }
}

/// 脚本管理器
class ScriptManager: ObservableObject {
    static let shared = ScriptManager()

    @Published var scripts: [Script] = []
    @Published var runningScripts: Set<UUID> = []

    private let scriptsDirectory: URL

    init() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        scriptsDirectory = documentsURL.appendingPathComponent("Scripts")

        try? fileManager.createDirectory(at: scriptsDirectory, withIntermediateDirectories: true)

        loadScripts()
        createExampleScripts()
    }

    private func loadScripts() {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(at: scriptsDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for url in contents {
            let ext = url.pathExtension.lowercased()
            let type: ScriptType?

            switch ext {
            case "js": type = .javascript
            case "py": type = .python
            case "lua": type = .lua
            default: type = nil
            }

            if let type = type, let source = try? String(contentsOf: url, encoding: .utf8) {
                let name = url.deletingPathExtension().lastPathComponent
                let script = Script(name: name, type: type, source: source)
                scripts.append(script)
            }
        }
    }

    private func createExampleScripts() {
        if scripts.isEmpty {
            // 批量调整片段速度
            let speedScript = Script(name: "批量调整速度", type: .javascript, source: """
                // 批量调整所有片段的速度
                var clips = getClips();
                var speedFactor = input.speedFactor || 1.5;

                for (var i = 0; i < clips.length; i++) {
                    applyEffect(clips[i].id, "speed", { factor: speedFactor });
                }

                output = { processed: clips.length };
                """)
            scripts.append(speedScript)

            // 自动添加转场
            let transitionScript = Script(name: "自动添加转场", type: .javascript, source: """
                // 在所有片段之间添加交叉溶解
                var clips = getClips();
                var transitionDuration = input.duration || 0.5;

                for (var i = 0; i < clips.length - 1; i++) {
                    applyEffect(clips[i].id + "_" + clips[i+1].id, "crossDissolve", {
                        duration: transitionDuration
                    });
                }

                output = { transitions: clips.length - 1 };
                """)
            scripts.append(transitionScript)
        }
    }

    /// 创建脚本
    func createScript(name: String, type: ScriptType, source: String = "") -> Script {
        let script = Script(name: name, type: type, source: source)
        scripts.append(script)
        saveScript(script)
        return script
    }

    /// 运行脚本
    func runScript(_ script: Script, input: [String: Any] = [:], completion: @escaping ([String: Any]?) -> Void) {
        runningScripts.insert(script.id)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = script.execute(input: input)

            DispatchQueue.main.async {
                self?.runningScripts.remove(script.id)
                completion(result)
            }
        }
    }

    /// 保存脚本
    func saveScript(_ script: Script) {
        let ext: String
        switch script.type {
        case .javascript: ext = "js"
        case .python: ext = "py"
        case .lua: ext = "lua"
        }

        let fileURL = scriptsDirectory.appendingPathComponent("\(script.name).\(ext)")
        try? script.source.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// 删除脚本
    func deleteScript(_ script: Script) {
        let ext: String
        switch script.type {
        case .javascript: ext = "js"
        case .python: ext = "py"
        case .lua: ext = "lua"
        }

        let fileURL = scriptsDirectory.appendingPathComponent("\(script.name).\(ext)")
        try? FileManager.default.removeItem(at: fileURL)

        scripts.removeAll { $0.id == script.id }
    }
}
