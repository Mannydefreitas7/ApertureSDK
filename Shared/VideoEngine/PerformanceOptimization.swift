//
//  PerformanceOptimization.swift
//  VideoEditor
//
//  性能优化模块 - Metal渲染、后台渲染、智能缓存、硬件解码
//

import Foundation
import AVFoundation
import Metal
import MetalKit
import MetalPerformanceShaders
import CoreVideo
import VideoToolbox
import Accelerate

// MARK: - Metal 渲染引擎

/// Metal 渲染配置
struct MetalRenderConfig {
    var pixelFormat: MTLPixelFormat = .bgra8Unorm
    var colorSpace: CGColorSpace? = CGColorSpace(name: CGColorSpace.sRGB)
    var useHDR: Bool = false
    var maxFramesInFlight: Int = 3
    var preferredFrameRate: Int = 60
    var enableMSAA: Bool = false
    var msaaSampleCount: Int = 4
}

/// Metal 渲染引擎
class MetalRenderEngine: ObservableObject {
    static let shared = MetalRenderEngine()

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    private var pipelineStates: [String: MTLRenderPipelineState] = [:]
    private var computePipelines: [String: MTLComputePipelineState] = [:]
    private var textureCache: CVMetalTextureCache?
    private var library: MTLLibrary?

    @Published var isInitialized: Bool = false
    @Published var gpuUsage: Float = 0
    @Published var renderTime: Double = 0

    var config: MetalRenderConfig = MetalRenderConfig()

    private let semaphore: DispatchSemaphore

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.semaphore = DispatchSemaphore(value: config.maxFramesInFlight)

        setupTextureCache()
        loadDefaultShaders()

        isInitialized = true
    }

    private func setupTextureCache() {
        var cache: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )

        if result == kCVReturnSuccess {
            textureCache = cache
        }
    }

    private func loadDefaultShaders() {
        // 加载默认Metal着色器库
        if let libraryURL = Bundle.main.url(forResource: "default", withExtension: "metallib") {
            library = try? device.makeLibrary(URL: libraryURL)
        }

        // 如果没有预编译库，尝试编译运行时着色器
        if library == nil {
            library = try? device.makeLibrary(source: defaultShaderSource, options: nil)
        }
    }

    // MARK: - 纹理管理

    /// 从CVPixelBuffer创建Metal纹理
    func createTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let cache = textureCache else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            config.pixelFormat,
            width,
            height,
            0,
            &cvTexture
        )

        guard result == kCVReturnSuccess, let cvTex = cvTexture else {
            return nil
        }

        return CVMetalTextureGetTexture(cvTex)
    }

    /// 创建空纹理
    func createTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat? = nil, usage: MTLTextureUsage = [.shaderRead, .shaderWrite, .renderTarget]) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat ?? config.pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage
        descriptor.storageMode = .private

        return device.makeTexture(descriptor: descriptor)
    }

    // MARK: - 渲染管线

    /// 创建渲染管线
    func createRenderPipeline(
        vertexFunction: String,
        fragmentFunction: String,
        pixelFormat: MTLPixelFormat? = nil
    ) -> MTLRenderPipelineState? {
        let key = "\(vertexFunction)_\(fragmentFunction)"

        if let cached = pipelineStates[key] {
            return cached
        }

        guard let library = library,
              let vertexFunc = library.makeFunction(name: vertexFunction),
              let fragmentFunc = library.makeFunction(name: fragmentFunction) else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = pixelFormat ?? config.pixelFormat

        // 启用混合
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        // MSAA
        if config.enableMSAA {
            descriptor.rasterSampleCount = config.msaaSampleCount
        }

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }

        pipelineStates[key] = pipeline
        return pipeline
    }

    /// 创建计算管线
    func createComputePipeline(function: String) -> MTLComputePipelineState? {
        if let cached = computePipelines[function] {
            return cached
        }

        guard let library = library,
              let kernelFunc = library.makeFunction(name: function) else {
            return nil
        }

        guard let pipeline = try? device.makeComputePipelineState(function: kernelFunc) else {
            return nil
        }

        computePipelines[function] = pipeline
        return pipeline
    }

    // MARK: - 渲染操作

    /// 执行渲染命令
    func render(
        to texture: MTLTexture,
        pipeline: MTLRenderPipelineState,
        uniforms: MTLBuffer? = nil,
        textures: [MTLTexture] = [],
        vertices: MTLBuffer? = nil,
        vertexCount: Int = 0,
        completion: ((MTLCommandBuffer) -> Void)? = nil
    ) {
        semaphore.wait()

        let startTime = CACurrentMediaTime()

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            semaphore.signal()
            return
        }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            semaphore.signal()
            return
        }

        encoder.setRenderPipelineState(pipeline)

        // 设置uniform缓冲区
        if let uniforms = uniforms {
            encoder.setVertexBuffer(uniforms, offset: 0, index: 0)
            encoder.setFragmentBuffer(uniforms, offset: 0, index: 0)
        }

        // 设置纹理
        for (index, tex) in textures.enumerated() {
            encoder.setFragmentTexture(tex, index: index)
        }

        // 设置顶点
        if let vertices = vertices {
            encoder.setVertexBuffer(vertices, offset: 0, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        } else {
            // 使用全屏四边形
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        encoder.endEncoding()

        commandBuffer.addCompletedHandler { [weak self] buffer in
            self?.semaphore.signal()
            self?.renderTime = CACurrentMediaTime() - startTime

            DispatchQueue.main.async {
                completion?(buffer)
            }
        }

        commandBuffer.commit()
    }

    /// 执行计算命令
    func compute(
        pipeline: MTLComputePipelineState,
        inputTextures: [MTLTexture],
        outputTexture: MTLTexture,
        uniforms: MTLBuffer? = nil,
        completion: ((MTLCommandBuffer) -> Void)? = nil
    ) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        encoder.setComputePipelineState(pipeline)

        // 设置输入纹理
        for (index, tex) in inputTextures.enumerated() {
            encoder.setTexture(tex, index: index)
        }

        // 设置输出纹理
        encoder.setTexture(outputTexture, index: inputTextures.count)

        // 设置uniform
        if let uniforms = uniforms {
            encoder.setBuffer(uniforms, offset: 0, index: 0)
        }

        // 计算线程组大小
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (outputTexture.width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (outputTexture.height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        if let completion = completion {
            commandBuffer.addCompletedHandler { buffer in
                DispatchQueue.main.async {
                    completion(buffer)
                }
            }
        }

        commandBuffer.commit()
    }

    /// 应用MPS滤镜
    func applyMPSFilter(
        _ filter: MPSUnaryImageKernel,
        input: MTLTexture,
        output: MTLTexture,
        completion: (() -> Void)? = nil
    ) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        filter.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)

        if let completion = completion {
            commandBuffer.addCompletedHandler { _ in
                DispatchQueue.main.async {
                    completion()
                }
            }
        }

        commandBuffer.commit()
    }

    /// 刷新纹理缓存
    func flushTextureCache() {
        if let cache = textureCache {
            CVMetalTextureCacheFlush(cache, 0)
        }
    }

    // MARK: - 默认着色器

    private var defaultShaderSource: String {
        """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        struct Uniforms {
            float4x4 transform;
            float opacity;
            float brightness;
            float contrast;
            float saturation;
        };

        // 全屏顶点着色器
        vertex VertexOut fullscreenVertex(uint vertexID [[vertex_id]]) {
            float2 positions[4] = {
                float2(-1, -1),
                float2( 1, -1),
                float2(-1,  1),
                float2( 1,  1)
            };

            float2 texCoords[4] = {
                float2(0, 1),
                float2(1, 1),
                float2(0, 0),
                float2(1, 0)
            };

            VertexOut out;
            out.position = float4(positions[vertexID], 0, 1);
            out.texCoord = texCoords[vertexID];
            return out;
        }

        // 基础片段着色器
        fragment float4 basicFragment(
            VertexOut in [[stage_in]],
            texture2d<float> texture [[texture(0)]],
            constant Uniforms& uniforms [[buffer(0)]]
        ) {
            constexpr sampler s(filter::linear);
            float4 color = texture.sample(s, in.texCoord);

            // 应用亮度
            color.rgb += uniforms.brightness;

            // 应用对比度
            color.rgb = (color.rgb - 0.5) * uniforms.contrast + 0.5;

            // 应用饱和度
            float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
            color.rgb = mix(float3(gray), color.rgb, uniforms.saturation);

            // 应用透明度
            color.a *= uniforms.opacity;

            return color;
        }

        // 混合片段着色器
        fragment float4 blendFragment(
            VertexOut in [[stage_in]],
            texture2d<float> baseTexture [[texture(0)]],
            texture2d<float> blendTexture [[texture(1)]],
            constant Uniforms& uniforms [[buffer(0)]]
        ) {
            constexpr sampler s(filter::linear);
            float4 base = baseTexture.sample(s, in.texCoord);
            float4 blend = blendTexture.sample(s, in.texCoord);

            // 正常混合
            float4 result = mix(base, blend, blend.a * uniforms.opacity);
            return result;
        }

        // 高斯模糊计算着色器
        kernel void gaussianBlur(
            texture2d<float, access::read> input [[texture(0)]],
            texture2d<float, access::write> output [[texture(1)]],
            constant float& radius [[buffer(0)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;

            float4 sum = float4(0);
            float weightSum = 0;

            int r = int(radius);
            for (int y = -r; y <= r; y++) {
                for (int x = -r; x <= r; x++) {
                    uint2 pos = uint2(clamp(int(gid.x) + x, 0, int(input.get_width()) - 1),
                                      clamp(int(gid.y) + y, 0, int(input.get_height()) - 1));
                    float weight = exp(-(x*x + y*y) / (2 * radius * radius));
                    sum += input.read(pos) * weight;
                    weightSum += weight;
                }
            }

            output.write(sum / weightSum, gid);
        }

        // 色彩调整计算着色器
        kernel void colorAdjust(
            texture2d<float, access::read> input [[texture(0)]],
            texture2d<float, access::write> output [[texture(1)]],
            constant Uniforms& uniforms [[buffer(0)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;

            float4 color = input.read(gid);

            // 亮度
            color.rgb += uniforms.brightness;

            // 对比度
            color.rgb = (color.rgb - 0.5) * uniforms.contrast + 0.5;

            // 饱和度
            float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
            color.rgb = mix(float3(gray), color.rgb, uniforms.saturation);

            output.write(color, gid);
        }

        // LUT应用着色器
        kernel void applyLUT(
            texture2d<float, access::read> input [[texture(0)]],
            texture3d<float, access::sample> lut [[texture(1)]],
            texture2d<float, access::write> output [[texture(2)]],
            constant float& intensity [[buffer(0)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;

            constexpr sampler s(filter::linear);
            float4 color = input.read(gid);

            // 从LUT采样
            float3 lutCoord = color.rgb;
            float4 lutColor = lut.sample(s, lutCoord);

            // 混合原始颜色和LUT颜色
            color.rgb = mix(color.rgb, lutColor.rgb, intensity);

            output.write(color, gid);
        }

        // 转场混合着色器
        kernel void transitionBlend(
            texture2d<float, access::read> from [[texture(0)]],
            texture2d<float, access::read> to [[texture(1)]],
            texture2d<float, access::write> output [[texture(2)]],
            constant float& progress [[buffer(0)]],
            constant int& type [[buffer(1)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

            float4 fromColor = from.read(gid);
            float4 toColor = to.read(gid);

            float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
            float4 result;

            switch (type) {
                case 0: // 淡入淡出
                    result = mix(fromColor, toColor, progress);
                    break;
                case 1: // 从左滑入
                    result = uv.x < progress ? toColor : fromColor;
                    break;
                case 2: // 从右滑入
                    result = uv.x > (1.0 - progress) ? toColor : fromColor;
                    break;
                case 3: // 从上滑入
                    result = uv.y < progress ? toColor : fromColor;
                    break;
                case 4: // 从下滑入
                    result = uv.y > (1.0 - progress) ? toColor : fromColor;
                    break;
                case 5: // 圆形展开
                    {
                        float2 center = float2(0.5);
                        float dist = distance(uv, center);
                        result = dist < progress * 0.707 ? toColor : fromColor;
                    }
                    break;
                default:
                    result = mix(fromColor, toColor, progress);
            }

            output.write(result, gid);
        }
        """
    }
}

// MARK: - 后台渲染管理器

/// 后台渲染任务
struct BackgroundRenderTask: Identifiable {
    let id: UUID
    let name: String
    let type: RenderTaskType
    let priority: RenderPriority
    let inputURL: URL
    let outputURL: URL
    var settings: RenderSettings
    var progress: Double = 0
    var status: RenderTaskStatus = .pending
    var error: Error?
    var startTime: Date?
    var endTime: Date?

    enum RenderTaskType {
        case export
        case proxy
        case thumbnail
        case waveform
        case cache
        case transcode
    }

    enum RenderPriority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3

        static func < (lhs: RenderPriority, rhs: RenderPriority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    enum RenderTaskStatus {
        case pending
        case queued
        case processing
        case paused
        case completed
        case failed
        case cancelled
    }
}

/// 渲染设置
struct RenderSettings: Codable {
    var width: Int = 1920
    var height: Int = 1080
    var frameRate: Double = 30
    var videoBitRate: Int = 10_000_000
    var audioBitRate: Int = 192_000
    var audioSampleRate: Int = 48000
    var videoCodec: VideoCodec = .h264
    var audioCodec: AudioCodec = .aac
    var container: ContainerFormat = .mp4
    var quality: RenderQuality = .high
    var useHardwareAcceleration: Bool = true

    enum VideoCodec: String, Codable, CaseIterable {
        case h264 = "H.264"
        case h265 = "H.265/HEVC"
        case prores = "ProRes"
        case prores422 = "ProRes 422"
        case prores4444 = "ProRes 4444"
        case vp9 = "VP9"
        case av1 = "AV1"
    }

    enum AudioCodec: String, Codable, CaseIterable {
        case aac = "AAC"
        case mp3 = "MP3"
        case pcm = "PCM"
        case flac = "FLAC"
        case opus = "Opus"
    }

    enum ContainerFormat: String, Codable, CaseIterable {
        case mp4 = "MP4"
        case mov = "MOV"
        case mkv = "MKV"
        case webm = "WebM"
        case avi = "AVI"
    }

    enum RenderQuality: String, Codable, CaseIterable {
        case draft = "草稿"
        case preview = "预览"
        case standard = "标准"
        case high = "高质量"
        case maximum = "最高质量"
    }
}

/// 后台渲染管理器
class BackgroundRenderManager: ObservableObject {
    static let shared = BackgroundRenderManager()

    @Published var tasks: [BackgroundRenderTask] = []
    @Published var activeTaskCount: Int = 0
    @Published var isProcessing: Bool = false

    private var taskQueue: [BackgroundRenderTask] = []
    private let maxConcurrentTasks: Int
    private var currentExportSessions: [UUID: AVAssetExportSession] = [:]
    private let workQueue = DispatchQueue(label: "com.videoeditor.backgroundrender", qos: .utility, attributes: .concurrent)

    init() {
        // 根据CPU核心数确定并发数
        maxConcurrentTasks = max(1, ProcessInfo.processInfo.processorCount / 2)
    }

    /// 添加渲染任务
    func addTask(_ task: BackgroundRenderTask) -> UUID {
        var newTask = task
        newTask.status = .queued

        DispatchQueue.main.async {
            self.tasks.append(newTask)
            self.taskQueue.append(newTask)
            self.processNextTasks()
        }

        return task.id
    }

    /// 取消任务
    func cancelTask(_ taskId: UUID) {
        if let session = currentExportSessions[taskId] {
            session.cancelExport()
        }

        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].status = .cancelled
            tasks[index].endTime = Date()
        }

        taskQueue.removeAll { $0.id == taskId }
    }

    /// 暂停任务
    func pauseTask(_ taskId: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == taskId && $0.status == .processing }) {
            tasks[index].status = .paused
        }
    }

    /// 恢复任务
    func resumeTask(_ taskId: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == taskId && $0.status == .paused }) {
            tasks[index].status = .queued
            taskQueue.append(tasks[index])
            processNextTasks()
        }
    }

    /// 重试失败任务
    func retryTask(_ taskId: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == taskId && $0.status == .failed }) {
            tasks[index].status = .queued
            tasks[index].error = nil
            tasks[index].progress = 0
            taskQueue.append(tasks[index])
            processNextTasks()
        }
    }

    /// 清理已完成任务
    func clearCompletedTasks() {
        tasks.removeAll { $0.status == .completed || $0.status == .cancelled || $0.status == .failed }
    }

    /// 处理下一批任务
    private func processNextTasks() {
        guard activeTaskCount < maxConcurrentTasks else { return }

        // 按优先级排序
        taskQueue.sort { $0.priority > $1.priority }

        while activeTaskCount < maxConcurrentTasks && !taskQueue.isEmpty {
            let task = taskQueue.removeFirst()
            startTask(task)
        }

        isProcessing = activeTaskCount > 0
    }

    /// 开始任务
    private func startTask(_ task: BackgroundRenderTask) {
        activeTaskCount += 1

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].status = .processing
            tasks[index].startTime = Date()
        }

        workQueue.async { [weak self] in
            switch task.type {
            case .export:
                self?.processExportTask(task)
            case .proxy:
                self?.processProxyTask(task)
            case .thumbnail:
                self?.processThumbnailTask(task)
            case .waveform:
                self?.processWaveformTask(task)
            case .cache:
                self?.processCacheTask(task)
            case .transcode:
                self?.processTranscodeTask(task)
            }
        }
    }

    /// 完成任务
    private func completeTask(_ taskId: UUID, error: Error? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
                self.tasks[index].endTime = Date()

                if let error = error {
                    self.tasks[index].status = .failed
                    self.tasks[index].error = error
                } else {
                    self.tasks[index].status = .completed
                    self.tasks[index].progress = 1.0
                }
            }

            self.currentExportSessions.removeValue(forKey: taskId)
            self.activeTaskCount -= 1
            self.processNextTasks()
        }
    }

    /// 更新进度
    private func updateProgress(_ taskId: UUID, progress: Double) {
        DispatchQueue.main.async { [weak self] in
            if let index = self?.tasks.firstIndex(where: { $0.id == taskId }) {
                self?.tasks[index].progress = progress
            }
        }
    }

    // MARK: - 任务处理

    private func processExportTask(_ task: BackgroundRenderTask) {
        let asset = AVAsset(url: task.inputURL)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: getExportPreset(for: task.settings)) else {
            completeTask(task.id, error: NSError(domain: "ExportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"]))
            return
        }

        currentExportSessions[task.id] = exportSession

        exportSession.outputURL = task.outputURL
        exportSession.outputFileType = getOutputFileType(for: task.settings)
        exportSession.shouldOptimizeForNetworkUse = true

        // 进度监控
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            let progress = Double(exportSession.progress)
            self?.updateProgress(task.id, progress: progress)

            if exportSession.status == .completed || exportSession.status == .failed || exportSession.status == .cancelled {
                timer.invalidate()
            }
        }

        exportSession.exportAsynchronously { [weak self] in
            progressTimer.invalidate()

            switch exportSession.status {
            case .completed:
                self?.completeTask(task.id)
            case .failed:
                self?.completeTask(task.id, error: exportSession.error)
            case .cancelled:
                self?.completeTask(task.id, error: NSError(domain: "ExportError", code: -2, userInfo: [NSLocalizedDescriptionKey: "导出已取消"]))
            default:
                break
            }
        }
    }

    private func processProxyTask(_ task: BackgroundRenderTask) {
        let asset = AVAsset(url: task.inputURL)

        // 创建低分辨率代理
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            completeTask(task.id, error: NSError(domain: "ProxyError", code: -1))
            return
        }

        exportSession.outputURL = task.outputURL
        exportSession.outputFileType = .mp4

        exportSession.exportAsynchronously { [weak self] in
            if exportSession.status == .completed {
                self?.completeTask(task.id)
            } else {
                self?.completeTask(task.id, error: exportSession.error)
            }
        }
    }

    private func processThumbnailTask(_ task: BackgroundRenderTask) {
        let asset = AVAsset(url: task.inputURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)

        do {
            let image = try generator.copyCGImage(at: CMTime.zero, actualTime: nil)
            // 保存缩略图
            saveThumbnail(image, to: task.outputURL)
            completeTask(task.id)
        } catch {
            completeTask(task.id, error: error)
        }
    }

    private func processWaveformTask(_ task: BackgroundRenderTask) {
        // 生成音频波形数据
        let asset = AVAsset(url: task.inputURL)

        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            completeTask(task.id, error: NSError(domain: "WaveformError", code: -1))
            return
        }

        // 简化的波形生成
        do {
            let reader = try AVAssetReader(asset: asset)
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]

            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            reader.add(output)
            reader.startReading()

            var samples: [Float] = []
            while let buffer = output.copyNextSampleBuffer() {
                if let blockBuffer = CMSampleBufferGetDataBuffer(buffer) {
                    var length = 0
                    var data: UnsafeMutablePointer<Int8>?
                    CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &data)

                    if let data = data {
                        let int16Pointer = UnsafeRawPointer(data).bindMemory(to: Int16.self, capacity: length / 2)
                        for i in stride(from: 0, to: length / 2, by: 100) {
                            samples.append(Float(int16Pointer[i]) / Float(Int16.max))
                        }
                    }
                }

                updateProgress(task.id, progress: Double(samples.count) / 10000.0)
            }

            // 保存波形数据
            let waveformData = try JSONEncoder().encode(samples)
            try waveformData.write(to: task.outputURL)
            completeTask(task.id)
        } catch {
            completeTask(task.id, error: error)
        }
    }

    private func processCacheTask(_ task: BackgroundRenderTask) {
        // 预渲染缓存帧
        let asset = AVAsset(url: task.inputURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let duration = asset.duration.seconds
        let frameCount = Int(duration * task.settings.frameRate)

        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) / task.settings.frameRate, preferredTimescale: 600)
            if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
                // 缓存帧
                let frameURL = task.outputURL.appendingPathComponent("frame_\(i).jpg")
                saveThumbnail(image, to: frameURL)
            }

            updateProgress(task.id, progress: Double(i) / Double(frameCount))
        }

        completeTask(task.id)
    }

    private func processTranscodeTask(_ task: BackgroundRenderTask) {
        // 视频转码
        processExportTask(task)
    }

    // MARK: - 辅助方法

    private func getExportPreset(for settings: RenderSettings) -> String {
        switch (settings.width, settings.height) {
        case (_, 2160): return AVAssetExportPreset3840x2160
        case (_, 1080): return AVAssetExportPresetHighestQuality
        case (_, 720): return AVAssetExportPreset1280x720
        case (_, 480): return AVAssetExportPreset640x480
        default: return AVAssetExportPresetHighestQuality
        }
    }

    private func getOutputFileType(for settings: RenderSettings) -> AVFileType {
        switch settings.container {
        case .mp4: return .mp4
        case .mov: return .mov
        case .mkv: return .mp4 // MKV不直接支持，使用MP4
        case .webm: return .mp4 // WebM不直接支持
        case .avi: return .mp4  // AVI不被AVFoundation直接支持
        }
    }

    private func saveThumbnail(_ image: CGImage, to url: URL) {
        #if canImport(AppKit)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        if let tiffData = nsImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            try? jpegData.write(to: url)
        }
        #elseif canImport(UIKit)
        let uiImage = UIImage(cgImage: image)
        if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
            try? jpegData.write(to: url)
        }
        #endif
    }
}

// MARK: - 智能缓存系统

/// 缓存条目
struct CacheEntry {
    let key: String
    let data: Data
    let size: Int
    let createdAt: Date
    var lastAccessedAt: Date
    var accessCount: Int
    let expiresAt: Date?
}

/// 缓存策略
enum CacheEvictionPolicy {
    case lru // Least Recently Used
    case lfu // Least Frequently Used
    case fifo // First In First Out
    case ttl // Time To Live
}

/// 智能缓存管理器
class SmartCacheManager: ObservableObject {
    static let shared = SmartCacheManager()

    @Published var memoryUsage: Int64 = 0
    @Published var diskUsage: Int64 = 0
    @Published var hitRate: Double = 0

    private var memoryCache: [String: CacheEntry] = [:]
    private var diskCacheURL: URL
    private var maxMemorySize: Int64 = 500 * 1024 * 1024 // 500MB
    private var maxDiskSize: Int64 = 5 * 1024 * 1024 * 1024 // 5GB

    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0

    private let cacheQueue = DispatchQueue(label: "com.videoeditor.cache", qos: .utility, attributes: .concurrent)
    private var evictionPolicy: CacheEvictionPolicy = .lru

    init() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        diskCacheURL = documentsURL.appendingPathComponent("VideoCache")

        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        calculateDiskUsage()
    }

    // MARK: - 内存缓存

    /// 存入内存缓存
    func setMemory(_ data: Data, forKey key: String, ttl: TimeInterval? = nil) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let entry = CacheEntry(
                key: key,
                data: data,
                size: data.count,
                createdAt: Date(),
                lastAccessedAt: Date(),
                accessCount: 0,
                expiresAt: ttl != nil ? Date().addingTimeInterval(ttl!) : nil
            )

            self.memoryCache[key] = entry
            self.memoryUsage += Int64(data.count)

            self.evictMemoryIfNeeded()
        }
    }

    /// 从内存缓存获取
    func getMemory(forKey key: String) -> Data? {
        var result: Data?

        cacheQueue.sync { [weak self] in
            guard let self = self,
                  var entry = self.memoryCache[key] else {
                self?.cacheMisses += 1
                self?.updateHitRate()
                return
            }

            // 检查过期
            if let expiresAt = entry.expiresAt, Date() > expiresAt {
                self.memoryCache.removeValue(forKey: key)
                self.memoryUsage -= Int64(entry.size)
                self.cacheMisses += 1
                self.updateHitRate()
                return
            }

            entry.lastAccessedAt = Date()
            entry.accessCount += 1
            self.memoryCache[key] = entry

            self.cacheHits += 1
            self.updateHitRate()

            result = entry.data
        }

        return result
    }

    /// 清除内存缓存
    func clearMemoryCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.memoryCache.removeAll()
            self?.memoryUsage = 0
        }
    }

    private func evictMemoryIfNeeded() {
        while memoryUsage > maxMemorySize && !memoryCache.isEmpty {
            let keyToRemove: String?

            switch evictionPolicy {
            case .lru:
                keyToRemove = memoryCache.min { $0.value.lastAccessedAt < $1.value.lastAccessedAt }?.key
            case .lfu:
                keyToRemove = memoryCache.min { $0.value.accessCount < $1.value.accessCount }?.key
            case .fifo:
                keyToRemove = memoryCache.min { $0.value.createdAt < $1.value.createdAt }?.key
            case .ttl:
                keyToRemove = memoryCache.filter { $0.value.expiresAt != nil }.min { ($0.value.expiresAt ?? .distantFuture) < ($1.value.expiresAt ?? .distantFuture) }?.key
            }

            if let key = keyToRemove, let entry = memoryCache.removeValue(forKey: key) {
                memoryUsage -= Int64(entry.size)
            } else {
                break
            }
        }
    }

    // MARK: - 磁盘缓存

    /// 存入磁盘缓存
    func setDisk(_ data: Data, forKey key: String) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let fileURL = self.diskCacheURL.appendingPathComponent(self.sanitizeKey(key))

            do {
                try data.write(to: fileURL)
                self.diskUsage += Int64(data.count)
                self.evictDiskIfNeeded()
            } catch {
                print("Disk cache write error: \(error)")
            }
        }
    }

    /// 从磁盘缓存获取
    func getDisk(forKey key: String) -> Data? {
        var result: Data?

        cacheQueue.sync { [weak self] in
            guard let self = self else { return }

            let fileURL = self.diskCacheURL.appendingPathComponent(self.sanitizeKey(key))

            if FileManager.default.fileExists(atPath: fileURL.path) {
                result = try? Data(contentsOf: fileURL)

                // 更新访问时间
                try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)

                if result != nil {
                    self.cacheHits += 1
                } else {
                    self.cacheMisses += 1
                }
            } else {
                self.cacheMisses += 1
            }

            self.updateHitRate()
        }

        return result
    }

    /// 清除磁盘缓存
    func clearDiskCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default
            try? fileManager.removeItem(at: self.diskCacheURL)
            try? fileManager.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)

            DispatchQueue.main.async {
                self.diskUsage = 0
            }
        }
    }

    private func evictDiskIfNeeded() {
        guard diskUsage > maxDiskSize else { return }

        let fileManager = FileManager.default

        do {
            let files = try fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])

            // 按修改时间排序
            let sortedFiles = files.sorted { (url1, url2) -> Bool in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 < date2
            }

            var currentSize = diskUsage

            for fileURL in sortedFiles {
                guard currentSize > maxDiskSize else { break }

                if let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                    try fileManager.removeItem(at: fileURL)
                    currentSize -= Int64(fileSize)
                }
            }

            DispatchQueue.main.async {
                self.diskUsage = currentSize
            }
        } catch {
            print("Disk eviction error: \(error)")
        }
    }

    private func calculateDiskUsage() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default
            var totalSize: Int64 = 0

            if let files = try? fileManager.contentsOfDirectory(at: self.diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) {
                for file in files {
                    if let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                        totalSize += Int64(size)
                    }
                }
            }

            DispatchQueue.main.async {
                self.diskUsage = totalSize
            }
        }
    }

    private func sanitizeKey(_ key: String) -> String {
        return key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "?", with: "_")
    }

    private func updateHitRate() {
        let total = cacheHits + cacheMisses
        if total > 0 {
            DispatchQueue.main.async {
                self.hitRate = Double(self.cacheHits) / Double(total)
            }
        }
    }

    // MARK: - 帧缓存

    /// 缓存视频帧
    func cacheFrame(_ texture: MTLTexture, forKey key: String) {
        let device = texture.device

        let width = texture.width
        let height = texture.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let dataSize = bytesPerRow * height

        var data = Data(count: dataSize)
        data.withUnsafeMutableBytes { ptr in
            texture.getBytes(
                ptr.baseAddress!,
                bytesPerRow: bytesPerRow,
                from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: width, height: height, depth: 1)),
                mipmapLevel: 0
            )
        }

        setMemory(data, forKey: "frame_\(key)")
    }

    /// 获取缓存帧
    func getCachedFrame(forKey key: String, device: MTLDevice) -> MTLTexture? {
        guard let data = getMemory(forKey: "frame_\(key)") else { return nil }

        // 重建纹理
        // 这里需要知道原始尺寸，简化处理
        return nil
    }
}

// MARK: - 硬件解码管理器

/// 硬件解码配置
struct HardwareDecoderConfig {
    var enableHardwareDecoding: Bool = true
    var preferredDecoder: DecoderType = .auto
    var maxDecoderInstances: Int = 4
    var bufferPoolSize: Int = 8

    enum DecoderType {
        case auto
        case hardware
        case software
        case hybrid
    }
}

/// 硬件解码管理器
class HardwareDecoderManager: ObservableObject {
    static let shared = HardwareDecoderManager()

    @Published var isHardwareDecodingAvailable: Bool = false
    @Published var activeDecoders: Int = 0
    @Published var decodedFrameCount: Int = 0
    @Published var averageDecodeTime: Double = 0

    var config: HardwareDecoderConfig = HardwareDecoderConfig()

    private var decompressionSessions: [UUID: VTDecompressionSession] = [:]
    private var pixelBufferPool: CVPixelBufferPool?
    private let decodeQueue = DispatchQueue(label: "com.videoeditor.decode", qos: .userInteractive)

    private var decodeTimes: [Double] = []
    private let maxSampleCount = 100

    init() {
        checkHardwareDecodingSupport()
        setupPixelBufferPool()
    }

    /// 检查硬件解码支持
    private func checkHardwareDecodingSupport() {
        // 检查VideoToolbox硬件解码支持
        var specifier = CMFormatDescription.Extensions.Key.depth
        isHardwareDecodingAvailable = VTIsHardwareDecodeSupported(kCMVideoCodecType_H264)
    }

    /// 设置像素缓冲池
    private func setupPixelBufferPool() {
        let poolAttributes: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: config.bufferPoolSize
        ]

        let pixelBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 1920,
            kCVPixelBufferHeightKey: 1080,
            kCVPixelBufferMetalCompatibilityKey: true
        ]

        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pixelBufferPool
        )
    }

    /// 创建解码会话
    func createDecoderSession(
        formatDescription: CMVideoFormatDescription,
        id: UUID = UUID(),
        completion: @escaping (CVPixelBuffer?, CMTime) -> Void
    ) -> UUID {
        guard activeDecoders < config.maxDecoderInstances else {
            return id
        }

        var session: VTDecompressionSession?

        let decoderSpecification: [CFString: Any] = [
            kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder: config.enableHardwareDecoding
        ]

        let outputImageBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey: true
        ]

        var callbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: { (decompressionOutputRefCon, sourceFrameRefCon, status, infoFlags, imageBuffer, presentationTimeStamp, presentationDuration) in
                guard status == noErr, let pixelBuffer = imageBuffer else { return }

                // 调用完成回调
                if let completion = decompressionOutputRefCon?.assumingMemoryBound(to: ((CVPixelBuffer?, CMTime) -> Void).self).pointee {
                    completion(pixelBuffer, presentationTimeStamp)
                }
            },
            decompressionOutputRefCon: nil
        )

        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: decoderSpecification as CFDictionary,
            imageBufferAttributes: outputImageBufferAttributes as CFDictionary,
            outputCallback: &callbackRecord,
            decompressionSessionOut: &session
        )

        if status == noErr, let session = session {
            decompressionSessions[id] = session
            activeDecoders += 1
        }

        return id
    }

    /// 解码帧
    func decodeFrame(
        sessionId: UUID,
        sampleBuffer: CMSampleBuffer,
        flags: VTDecodeFrameFlags = [],
        completion: @escaping (CVPixelBuffer?, CMTime, Error?) -> Void
    ) {
        guard let session = decompressionSessions[sessionId] else {
            completion(nil, .zero, NSError(domain: "DecoderError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的解码会话"]))
            return
        }

        let startTime = CACurrentMediaTime()

        var flagsOut: VTDecodeInfoFlags = []

        let status = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: flags,
            frameRefcon: nil,
            infoFlagsOut: &flagsOut
        )

        if status == noErr {
            // 等待解码完成
            VTDecompressionSessionWaitForAsynchronousFrames(session)

            let decodeTime = CACurrentMediaTime() - startTime
            recordDecodeTime(decodeTime)

            decodedFrameCount += 1
        } else {
            completion(nil, .zero, NSError(domain: "DecoderError", code: Int(status), userInfo: nil))
        }
    }

    /// 同步解码
    func decodeFrameSync(
        sessionId: UUID,
        sampleBuffer: CMSampleBuffer
    ) -> CVPixelBuffer? {
        guard let session = decompressionSessions[sessionId] else { return nil }

        var pixelBuffer: CVPixelBuffer?
        var flagsOut: VTDecodeInfoFlags = []

        // 使用同步解码而不是带回调的异步解码
        let status = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [],
            frameRefcon: nil,
            infoFlagsOut: &flagsOut
        )

        // 注意：完整实现需要使用VTDecompressionSessionDecodeFrameWithOutputHandler
        // 或者设置正确的回调来获取解码后的帧

        return pixelBuffer
    }

    /// 销毁解码会话
    func destroySession(_ sessionId: UUID) {
        if let session = decompressionSessions.removeValue(forKey: sessionId) {
            VTDecompressionSessionInvalidate(session)
            activeDecoders -= 1
        }
    }

    /// 销毁所有会话
    func destroyAllSessions() {
        for (id, session) in decompressionSessions {
            VTDecompressionSessionInvalidate(session)
        }
        decompressionSessions.removeAll()
        activeDecoders = 0
    }

    /// 获取像素缓冲区
    func getPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?

        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true
        ]

        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        return pixelBuffer
    }

    private func recordDecodeTime(_ time: Double) {
        decodeTimes.append(time)
        if decodeTimes.count > maxSampleCount {
            decodeTimes.removeFirst()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.averageDecodeTime = self.decodeTimes.reduce(0, +) / Double(self.decodeTimes.count)
        }
    }
}

// MARK: - 性能监控器

/// 性能指标
struct PerformanceMetrics {
    var cpuUsage: Double = 0
    var memoryUsage: Int64 = 0
    var gpuUsage: Double = 0
    var fps: Double = 0
    var droppedFrames: Int = 0
    var renderTime: Double = 0
    var decodeTime: Double = 0
    var encodeTime: Double = 0
    var diskReadSpeed: Double = 0
    var diskWriteSpeed: Double = 0
}

/// 性能监控器
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    @Published var metrics: PerformanceMetrics = PerformanceMetrics()
    @Published var isMonitoring: Bool = false

    private var displayLink: CADisplayLink?
    private var frameTimestamps: [CFTimeInterval] = []
    private var lastFrameTime: CFTimeInterval = 0

    private var cpuTimer: Timer?
    private let monitorQueue = DispatchQueue(label: "com.videoeditor.performance")

    init() {}

    /// 开始监控
    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true

        // CPU监控
        cpuTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCPUUsage()
            self?.updateMemoryUsage()
        }

        // FPS监控
        #if canImport(AppKit)
        // macOS使用CVDisplayLink
        #else
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.add(to: .main, forMode: .common)
        #endif
    }

    /// 停止监控
    func stopMonitoring() {
        isMonitoring = false

        cpuTimer?.invalidate()
        cpuTimer = nil

        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkCallback(_ link: CADisplayLink) {
        let currentTime = link.timestamp
        frameTimestamps.append(currentTime)

        // 保留最近60帧的时间戳
        if frameTimestamps.count > 60 {
            frameTimestamps.removeFirst()
        }

        // 计算FPS
        if frameTimestamps.count >= 2 {
            let timeRange = frameTimestamps.last! - frameTimestamps.first!
            let fps = Double(frameTimestamps.count - 1) / timeRange

            DispatchQueue.main.async { [weak self] in
                self?.metrics.fps = fps
            }
        }
    }

    private func updateCPUUsage() {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)

        let threadsResult = task_threads(mach_task_self_, &threadsList, &threadsCount)

        if threadsResult == KERN_SUCCESS, let threads = threadsList {
            for index in 0..<Int(threadsCount) {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

                let infoResult = withUnsafeMutablePointer(to: &threadInfo) { ptr in
                    ptr.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) { intPtr in
                        thread_info(threads[index], thread_flavor_t(THREAD_BASIC_INFO), intPtr, &threadInfoCount)
                    }
                }

                guard infoResult == KERN_SUCCESS else { continue }

                let threadBasicInfo = threadInfo
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU += Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }

            let size = vm_size_t(threadsCount) * vm_size_t(MemoryLayout<thread_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), size)
        }

        DispatchQueue.main.async { [weak self] in
            self?.metrics.cpuUsage = totalUsageOfCPU
        }
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }

        if result == KERN_SUCCESS {
            DispatchQueue.main.async { [weak self] in
                self?.metrics.memoryUsage = Int64(info.resident_size)
            }
        }
    }

    /// 记录渲染时间
    func recordRenderTime(_ time: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.metrics.renderTime = time
        }
    }

    /// 记录解码时间
    func recordDecodeTime(_ time: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.metrics.decodeTime = time
        }
    }

    /// 记录编码时间
    func recordEncodeTime(_ time: Double) {
        DispatchQueue.main.async { [weak self] in
            self?.metrics.encodeTime = time
        }
    }

    /// 记录丢帧
    func recordDroppedFrame() {
        DispatchQueue.main.async { [weak self] in
            self?.metrics.droppedFrames += 1
        }
    }
}

// MARK: - 内存压力处理器

/// 内存压力处理器
class MemoryPressureHandler: ObservableObject {
    static let shared = MemoryPressureHandler()

    @Published var currentPressureLevel: MemoryPressureLevel = .normal

    enum MemoryPressureLevel: Int {
        case normal = 0
        case warning = 1
        case critical = 2
        case urgent = 3
    }

    private var dispatchSource: DispatchSourceMemoryPressure?

    var onMemoryWarning: (() -> Void)?
    var onMemoryCritical: (() -> Void)?

    init() {
        setupMemoryPressureMonitoring()
    }

    private func setupMemoryPressureMonitoring() {
        dispatchSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)

        dispatchSource?.setEventHandler { [weak self] in
            guard let self = self else { return }

            let event = self.dispatchSource?.data ?? []

            if event.contains(.critical) {
                self.currentPressureLevel = .critical
                self.handleCriticalMemoryPressure()
            } else if event.contains(.warning) {
                self.currentPressureLevel = .warning
                self.handleWarningMemoryPressure()
            }
        }

        dispatchSource?.setCancelHandler { [weak self] in
            self?.dispatchSource = nil
        }

        dispatchSource?.resume()
    }

    private func handleWarningMemoryPressure() {
        // 清理非关键缓存
        SmartCacheManager.shared.clearMemoryCache()

        // 通知回调
        onMemoryWarning?()
    }

    private func handleCriticalMemoryPressure() {
        // 清理所有缓存
        SmartCacheManager.shared.clearMemoryCache()
        SmartCacheManager.shared.clearDiskCache()

        // 释放解码器
        HardwareDecoderManager.shared.destroyAllSessions()

        // 刷新Metal纹理缓存
        MetalRenderEngine.shared?.flushTextureCache()

        // 通知回调
        onMemoryCritical?()
    }

    /// 获取可用内存
    func getAvailableMemory() -> Int64 {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var vmStats = vm_statistics64()
        var infoCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &infoCount)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let freeMemory = Int64(vmStats.free_count) * Int64(pageSize)
        return freeMemory
    }

    /// 获取总内存
    func getTotalMemory() -> Int64 {
        return Int64(ProcessInfo.processInfo.physicalMemory)
    }

    deinit {
        dispatchSource?.cancel()
    }
}
