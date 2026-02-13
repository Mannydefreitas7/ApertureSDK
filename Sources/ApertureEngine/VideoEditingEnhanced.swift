import Foundation
import AVFoundation
import CoreImage
import CoreMedia
import Accelerate
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 1. 视频编辑增强模块

// MARK: - 多机位编辑

struct MultiCamProject: Identifiable, Codable {
    let id: UUID
    var name: String
    var angles: [CameraAngle]
    var syncPoint: CMTime
    var activeAngleId: UUID?
    var cuts: [MultiCamCut]

    init(id: UUID = UUID(), name: String = "多机位项目") {
        self.id = id
        self.name = name
        self.angles = []
        self.syncPoint = .zero
        self.cuts = []
    }
}

struct CameraAngle: Identifiable, Codable {
    let id: UUID
    var name: String
    var clipId: UUID
    var syncOffset: CMTime  // 相对于同步点的偏移
    var isAudioSource: Bool  // 是否作为主音频源

    init(id: UUID = UUID(), name: String, clipId: UUID, syncOffset: CMTime = .zero, isAudioSource: Bool = false) {
        self.id = id
        self.name = name
        self.clipId = clipId
        self.syncOffset = syncOffset
        self.isAudioSource = isAudioSource
    }
}

struct MultiCamCut: Identifiable, Codable {
    let id: UUID
    var angleId: UUID
    var startTime: CMTime
    var endTime: CMTime
}

class MultiCamEditor: ObservableObject {
    static let shared = MultiCamEditor()

    @Published var currentProject: MultiCamProject?
    @Published var isLivePreview = false

    private init() {}

    // 创建多机位项目
    func createProject(name: String, clips: [Clip]) -> MultiCamProject {
        var project = MultiCamProject(name: name)

        for (index, clip) in clips.enumerated() {
            let angle = CameraAngle(
                name: "机位 \(index + 1)",
                clipId: clip.id,
                isAudioSource: index == 0
            )
            project.angles.append(angle)
        }

        currentProject = project
        return project
    }

    // 自动同步（基于音频波形）
    func autoSync() async throws {
        guard var project = currentProject else { return }

        // 使用音频波形匹配进行同步
        // 这里简化实现，实际需要使用互相关算法
        for i in 1..<project.angles.count {
            let offset = try await calculateAudioOffset(
                reference: project.angles[0].clipId,
                target: project.angles[i].clipId
            )
            project.angles[i].syncOffset = offset
        }

        currentProject = project
    }

    private func calculateAudioOffset(reference: UUID, target: UUID) async throws -> CMTime {
        // 简化实现 - 实际应使用FFT和互相关
        return CMTime(seconds: 0, preferredTimescale: 600)
    }

    // 切换机位
    func switchAngle(to angleId: UUID, at time: CMTime) {
        guard var project = currentProject else { return }

        // 结束当前片段
        if let lastCut = project.cuts.last, lastCut.endTime == .positiveInfinity {
            project.cuts[project.cuts.count - 1].endTime = time
        }

        // 添加新切换点
        let cut = MultiCamCut(
            id: UUID(),
            angleId: angleId,
            startTime: time,
            endTime: .positiveInfinity
        )
        project.cuts.append(cut)
        project.activeAngleId = angleId

        currentProject = project
    }

    // 导出多机位编辑结果
    func exportToTimeline() -> [Clip] {
        // 将多机位切换转换为普通时间线片段
        return []
    }
}

// MARK: - 代理编辑

enum ProxyQuality: String, Codable, CaseIterable {
    case quarter = "1/4"
    case half = "1/2"
    case full = "原始"

    var scale: CGFloat {
        switch self {
        case .quarter: return 0.25
        case .half: return 0.5
        case .full: return 1.0
        }
    }
}

class ProxyManager: ObservableObject {
    static let shared = ProxyManager()

    @Published var isGeneratingProxies = false
    @Published var proxyProgress: Double = 0
    @Published var proxyQuality: ProxyQuality = .half
    @Published var useProxyForPlayback = true

    private var proxyCache: [UUID: URL] = [:]

    private init() {}

    // 生成代理文件
    func generateProxy(for clip: Clip, quality: ProxyQuality = .half) async throws -> URL {
        if let cached = proxyCache[clip.id] {
            return cached
        }

        isGeneratingProxies = true
        defer { isGeneratingProxies = false }

        let asset = clip.asset

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(clip.id)_proxy_\(quality.rawValue).mp4")

        // 创建导出会话
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: quality == .quarter ? AVAssetExportPreset640x480 : AVAssetExportPreset1280x720
        ) else {
            throw ProxyError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        await exportSession.export()

        if exportSession.status == .completed {
            proxyCache[clip.id] = outputURL
            return outputURL
        } else {
            throw ProxyError.exportFailed
        }
    }

    // 批量生成代理
    func generateProxies(for clips: [Clip]) async {
        for (index, clip) in clips.enumerated() {
            do {
                _ = try await generateProxy(for: clip, quality: proxyQuality)
                proxyProgress = Double(index + 1) / Double(clips.count)
            } catch {
                print("Failed to generate proxy for \(clip.name): \(error)")
            }
        }
    }

    // 获取代理或原始资源
    func getAsset(for clip: Clip) -> AVAsset? {
        if useProxyForPlayback, let proxyURL = proxyCache[clip.id] {
            return AVAsset(url: proxyURL)
        }
        return clip.asset
    }

    // 清理代理缓存
    func clearCache() {
        for url in proxyCache.values {
            try? FileManager.default.removeItem(at: url)
        }
        proxyCache.removeAll()
    }

    enum ProxyError: Error {
        case invalidAsset
        case exportFailed
    }
}

// MARK: - 嵌套序列（复合片段）

struct CompoundClip: Identifiable {
    let id: UUID
    var name: String
    var clips: [Clip]
    var duration: CMTime
    var settings: ProjectSettings

    init(id: UUID = UUID(), name: String, clips: [Clip], settings: ProjectSettings) {
        self.id = id
        self.name = name
        self.clips = clips
        self.settings = settings

        // 计算总时长
        self.duration = clips.reduce(.zero) { max($0, $1.startTime + $1.duration) }
    }
}

class CompoundClipManager: ObservableObject {
    static let shared = CompoundClipManager()

    @Published var compoundClips: [CompoundClip] = []

    private init() {}

    // 创建复合片段
    func createCompoundClip(name: String, from clips: [Clip], settings: ProjectSettings) -> CompoundClip {
        let compound = CompoundClip(name: name, clips: clips, settings: settings)
        compoundClips.append(compound)
        return compound
    }

    // 解散复合片段
    func dissolveCompoundClip(_ compound: CompoundClip) -> [Clip] {
        compoundClips.removeAll { $0.id == compound.id }
        return compound.clips
    }

    // 渲染复合片段为单个视频
    func renderCompoundClip(_ compound: CompoundClip) async throws -> URL {
        // 使用 CompositionBuilder 渲染
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(compound.id).mp4")

        // 实现渲染逻辑
        return outputURL
    }
}

// MARK: - 冻结帧

struct FreezeFrame: Identifiable, Codable {
    let id: UUID
    var sourceClipId: UUID
    var frameTime: CMTime
    var duration: CMTime
    var position: CMTime  // 在时间线上的位置

    init(id: UUID = UUID(), sourceClipId: UUID, frameTime: CMTime, duration: CMTime = CMTime(seconds: 2, preferredTimescale: 600), position: CMTime) {
        self.id = id
        self.sourceClipId = sourceClipId
        self.frameTime = frameTime
        self.duration = duration
        self.position = position
    }
}

class FreezeFrameManager {
    static let shared = FreezeFrameManager()

    private init() {}

    // 创建冻结帧
    func createFreezeFrame(from clip: Clip, at time: CMTime, duration: CMTime = CMTime(seconds: 2, preferredTimescale: 600)) async throws -> CGImage? {
        let asset = clip.asset

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
        return cgImage
    }

    // 导出冻结帧为图片
    func exportFreezeFrame(_ image: CGImage, to url: URL) throws {
        #if canImport(AppKit)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw FreezeFrameError.exportFailed
        }
        try pngData.write(to: url)
        #endif
    }

    enum FreezeFrameError: Error {
        case exportFailed
    }
}

// MARK: - 倒放视频

class ReverseVideoProcessor {
    static let shared = ReverseVideoProcessor()

    private init() {}

    // 倒放视频
    func reverseVideo(asset: AVAsset, outputURL: URL, progress: @escaping (Double) -> Void) async throws {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw ReverseError.noVideoTrack
        }

        let duration = asset.duration
        let frameRate = videoTrack.nominalFrameRate
        let totalFrames = Int(CMTimeGetSeconds(duration) * Double(frameRate))

        // 创建图像生成器
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        // 提取所有帧
        var frames: [CGImage] = []
        for i in 0..<totalFrames {
            let time = CMTime(value: CMTimeValue(i), timescale: CMTimeScale(frameRate))
            if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
                frames.append(image)
            }
            progress(Double(i) / Double(totalFrames) * 0.5)
        }

        // 反转帧顺序
        frames.reverse()

        // 写入新视频
        try await writeFramesToVideo(frames: frames, outputURL: outputURL, frameRate: frameRate) { p in
            progress(0.5 + p * 0.5)
        }
    }

    private func writeFramesToVideo(frames: [CGImage], outputURL: URL, frameRate: Float, progress: @escaping (Double) -> Void) async throws {
        guard let firstFrame = frames.first else { return }

        let size = CGSize(width: firstFrame.width, height: firstFrame.height)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: nil
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))

        for (index, frame) in frames.enumerated() {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            if let pixelBuffer = pixelBuffer(from: frame, size: size) {
                let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(index))
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            }

            progress(Double(index) / Double(frames.count))
        }

        input.markAsFinished()
        await writer.finishWriting()
    }

    private func pixelBuffer(from image: CGImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )

        context?.draw(image, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }

    enum ReverseError: Error {
        case noVideoTrack
    }
}

// MARK: - 镜头校正

struct LensCorrectionParams: Codable {
    var distortionK1: Float = 0
    var distortionK2: Float = 0
    var distortionK3: Float = 0
    var chromaticAberration: Float = 0
    var vignette: Float = 0
}

enum LensCorrectionPreset: String, CaseIterable {
    case none = "无"
    case gopro = "GoPro"
    case fisheye = "鱼眼"
    case wideAngle = "广角"
    case actionCam = "运动相机"

    var correction: LensCorrectionParams {
        switch self {
        case .none:
            return LensCorrectionParams()
        case .gopro:
            return LensCorrectionParams(distortionK1: -0.3, distortionK2: 0.1)
        case .fisheye:
            return LensCorrectionParams(distortionK1: -0.5, distortionK2: 0.2, distortionK3: -0.05)
        case .wideAngle:
            return LensCorrectionParams(distortionK1: -0.2, distortionK2: 0.05)
        case .actionCam:
            return LensCorrectionParams(distortionK1: -0.25, distortionK2: 0.08, vignette: 0.1)
        }
    }
}

class LensCorrectionFilter {
    static func apply(to image: CIImage, correction: LensCorrectionParams) -> CIImage {
        // 使用 CIFilter 进行畸变校正
        // 实际实现需要自定义 Metal shader

        var result = image

        // 暗角校正
        if correction.vignette != 0 {
            if let vignetteFilter = CIFilter(name: "CIVignette") {
                vignetteFilter.setValue(result, forKey: kCIInputImageKey)
                vignetteFilter.setValue(-correction.vignette, forKey: kCIInputIntensityKey)
                vignetteFilter.setValue(1.0, forKey: kCIInputRadiusKey)
                if let output = vignetteFilter.outputImage {
                    result = output
                }
            }
        }

        return result
    }
}

// MARK: - 视频降噪

enum DenoiseStrength: String, CaseIterable {
    case light = "轻度"
    case medium = "中度"
    case strong = "强力"

    var value: Float {
        switch self {
        case .light: return 0.3
        case .medium: return 0.6
        case .strong: return 1.0
        }
    }
}

class VideoDenoiser {
    static func denoise(_ image: CIImage, strength: DenoiseStrength) -> CIImage {
        guard let filter = CIFilter(name: "CINoiseReduction") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(strength.value * 0.02, forKey: "inputNoiseLevel")
        filter.setValue(strength.value * 0.4, forKey: "inputSharpness")

        return filter.outputImage ?? image
    }
}

// MARK: - 视频锐化

struct SharpenSettings: Codable {
    var amount: Float = 0.5
    var radius: Float = 1.0
    var threshold: Float = 0
}

class VideoSharpener {
    static func sharpen(_ image: CIImage, settings: SharpenSettings) -> CIImage {
        guard let filter = CIFilter(name: "CISharpenLuminance") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(settings.amount, forKey: kCIInputSharpnessKey)

        return filter.outputImage ?? image
    }

    static func unsharpMask(_ image: CIImage, settings: SharpenSettings) -> CIImage {
        guard let filter = CIFilter(name: "CIUnsharpMask") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(settings.amount * 2, forKey: kCIInputIntensityKey)
        filter.setValue(settings.radius, forKey: kCIInputRadiusKey)

        return filter.outputImage ?? image
    }
}

// MARK: - 色彩匹配

class ColorMatcher {
    static let shared = ColorMatcher()

    private init() {}

    // 提取参考帧的颜色统计信息
    func extractColorStats(from image: CGImage) -> ColorStats {
        // 简化实现 - 实际应计算直方图和颜色矩
        return ColorStats(
            meanR: 0.5, meanG: 0.5, meanB: 0.5,
            stdR: 0.2, stdG: 0.2, stdB: 0.2
        )
    }

    // 匹配目标图像到参考颜色
    func matchColor(target: CIImage, to reference: ColorStats) -> CIImage {
        // 使用颜色转移算法
        // 简化实现
        return target
    }

    struct ColorStats {
        var meanR: Float
        var meanG: Float
        var meanB: Float
        var stdR: Float
        var stdG: Float
        var stdB: Float
    }
}

// MARK: - HDR 支持

enum HDRFormat: String, CaseIterable {
    case sdr = "SDR"
    case hdr10 = "HDR10"
    case hlg = "HLG"
    case dolbyVision = "Dolby Vision"
}

class HDRProcessor {
    static let shared = HDRProcessor()

    private init() {}

    // 检测视频 HDR 格式
    func detectHDRFormat(asset: AVAsset) -> HDRFormat {
        guard let track = asset.tracks(withMediaType: .video).first else {
            return .sdr
        }

        // 检查色彩空间和传输函数
        // 简化实现
        return .sdr
    }

    // HDR 转 SDR (色调映射)
    func toneMapToSDR(_ image: CIImage) -> CIImage {
        // 实现色调映射算法
        return image
    }

    // SDR 转 HDR
    func expandToHDR(_ image: CIImage, format: HDRFormat) -> CIImage {
        // 实现逆色调映射
        return image
    }
}

// MARK: - 360°/VR 视频编辑

enum ProjectionType: String, CaseIterable, Codable {
    case equirectangular = "等距柱状投影"
    case cubemap = "立方体贴图"
    case fisheye = "鱼眼"
}

struct VRVideoSettings: Codable {
    var projection: ProjectionType = .equirectangular
    var stereoscopic: Bool = false
    var fieldOfView: Double = 90
    var initialYaw: Double = 0
    var initialPitch: Double = 0
    var initialRoll: Double = 0
}

class VRVideoEditor: ObservableObject {
    static let shared = VRVideoEditor()

    @Published var settings = VRVideoSettings()
    @Published var currentYaw: Double = 0
    @Published var currentPitch: Double = 0

    private init() {}

    // 提取平面视频区域
    func extractFlatView(from vrImage: CIImage, yaw: Double, pitch: Double, fov: Double) -> CIImage {
        // 从全景图中提取特定角度的平面视图
        // 需要实现投影转换
        return vrImage
    }

    // 添加 VR 文字/贴纸
    func addOverlay(text: String, at position: (yaw: Double, pitch: Double)) {
        // 在 3D 空间中放置文字
    }

    // 导出平面视频
    func exportFlatVideo(from vrAsset: AVAsset, path: [(time: CMTime, yaw: Double, pitch: Double)]) async throws -> URL {
        // 按照路径导出平面视频
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("vr_export.mp4")
        return outputURL
    }
}

// MARK: - 裁剪和旋转

struct CropSettings: Codable {
    var rect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)  // 归一化坐标
    var rotation: Double = 0  // 角度
    var flipHorizontal: Bool = false
    var flipVertical: Bool = false
    var aspectRatio: AspectRatio = .free

    enum AspectRatio: String, Codable, CaseIterable {
        case free = "自由"
        case ratio16x9 = "16:9"
        case ratio9x16 = "9:16"
        case ratio4x3 = "4:3"
        case ratio3x4 = "3:4"
        case ratio1x1 = "1:1"
        case ratio21x9 = "21:9"

        var value: CGFloat? {
            switch self {
            case .free: return nil
            case .ratio16x9: return 16.0/9.0
            case .ratio9x16: return 9.0/16.0
            case .ratio4x3: return 4.0/3.0
            case .ratio3x4: return 3.0/4.0
            case .ratio1x1: return 1.0
            case .ratio21x9: return 21.0/9.0
            }
        }
    }
}

class CropAndRotateProcessor {
    static func apply(to image: CIImage, settings: CropSettings) -> CIImage {
        var result = image

        // 裁剪
        let imageSize = result.extent.size
        let cropRect = CGRect(
            x: settings.rect.origin.x * imageSize.width,
            y: settings.rect.origin.y * imageSize.height,
            width: settings.rect.width * imageSize.width,
            height: settings.rect.height * imageSize.height
        )
        result = result.cropped(to: cropRect)

        // 旋转
        if settings.rotation != 0 {
            let radians = settings.rotation * .pi / 180
            result = result.transformed(by: CGAffineTransform(rotationAngle: radians))
        }

        // 水平翻转
        if settings.flipHorizontal {
            result = result.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        }

        // 垂直翻转
        if settings.flipVertical {
            result = result.transformed(by: CGAffineTransform(scaleX: 1, y: -1))
        }

        return result
    }
}
