//
//  LiveStreamingSystem.swift
//  VideoEditor
//
//  直播功能模块 - 推流、虚拟摄像头、实时滤镜、直播录制
//

import Foundation
import AVFoundation
import CoreImage
import CoreMedia
import VideoToolbox
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 推流协议

/// 推流协议类型
enum StreamingProtocol: String, CaseIterable {
    case rtmp = "RTMP"
    case rtmps = "RTMPS"
    case hls = "HLS"
    case webrtc = "WebRTC"
    case srt = "SRT"

    var defaultPort: Int {
        switch self {
        case .rtmp: return 1935
        case .rtmps: return 443
        case .hls: return 80
        case .webrtc: return 443
        case .srt: return 9000
        }
    }
}

/// 推流平台
enum StreamingPlatform: String, CaseIterable {
    case custom = "自定义"
    case youtube = "YouTube"
    case twitch = "Twitch"
    case facebook = "Facebook"
    case bilibili = "哔哩哔哩"
    case douyu = "斗鱼"
    case huya = "虎牙"
    case kuaishou = "快手"
    case douyin = "抖音"
    case wechat = "微信视频号"

    var rtmpURL: String {
        switch self {
        case .custom: return ""
        case .youtube: return "rtmp://a.rtmp.youtube.com/live2"
        case .twitch: return "rtmp://live.twitch.tv/app"
        case .facebook: return "rtmps://live-api-s.facebook.com:443/rtmp"
        case .bilibili: return "rtmp://live-push.bilivideo.com/live-bvc"
        case .douyu: return "rtmp://sendtc.douyu.com"
        case .huya: return "rtmp://bs.huya.com/huyalive"
        case .kuaishou: return "rtmp://livepush.kwai.com/gifshow"
        case .douyin: return "rtmp://push-rtmp-f5.douyincdn.com/stage"
        case .wechat: return "rtmp://wx.live-send.acg.tv/live-wx"
        }
    }
}

// MARK: - 推流配置

/// 推流配置
struct StreamConfiguration {
    var platform: StreamingPlatform = .custom
    var streamURL: String = ""
    var streamKey: String = ""
    var `protocol`: StreamingProtocol = .rtmp

    // 视频设置
    var videoWidth: Int = 1920
    var videoHeight: Int = 1080
    var frameRate: Int = 30
    var videoBitrate: Int = 4500000 // 4.5 Mbps
    var keyframeInterval: Int = 2 // 秒
    var videoCodec: VideoCodec = .h264
    var profile: H264Profile = .high
    var preset: EncoderPreset = .veryfast

    // 音频设置
    var audioBitrate: Int = 128000 // 128 kbps
    var audioSampleRate: Int = 48000
    var audioChannels: Int = 2
    var audioCodec: AudioCodec = .aac

    // 高级设置
    var enableAdaptiveBitrate: Bool = true
    var minBitrate: Int = 1000000
    var maxBitrate: Int = 8000000
    var bufferSize: Int = 2 // 秒
    var lowLatencyMode: Bool = false
    var enableHardwareEncoder: Bool = true

    enum VideoCodec: String, CaseIterable {
        case h264 = "H.264"
        case hevc = "HEVC"
        case av1 = "AV1"
    }

    enum AudioCodec: String, CaseIterable {
        case aac = "AAC"
        case opus = "Opus"
    }

    enum H264Profile: String, CaseIterable {
        case baseline = "Baseline"
        case main = "Main"
        case high = "High"
    }

    enum EncoderPreset: String, CaseIterable {
        case ultrafast = "ultrafast"
        case superfast = "superfast"
        case veryfast = "veryfast"
        case faster = "faster"
        case fast = "fast"
        case medium = "medium"
        case slow = "slow"
    }

    var fullStreamURL: String {
        if platform == .custom {
            return streamURL.isEmpty ? "" : "\(streamURL)/\(streamKey)"
        } else {
            return "\(platform.rtmpURL)/\(streamKey)"
        }
    }
}

// MARK: - 推流状态

/// 推流状态
enum StreamingState {
    case idle
    case connecting
    case streaming
    case reconnecting
    case error(Error)
    case stopped
}

/// 推流统计
struct StreamingStatistics {
    var duration: TimeInterval = 0
    var sentBytes: Int64 = 0
    var sentFrames: Int = 0
    var droppedFrames: Int = 0
    var currentBitrate: Int = 0
    var averageBitrate: Int = 0
    var fps: Double = 0
    var rtt: Double = 0 // Round-trip time
    var bufferHealth: Double = 1.0
    var cpuUsage: Double = 0
    var memoryUsage: Int64 = 0
}

// MARK: - RTMP推流器

/// RTMP推流管理器
class RTMPStreamManager: NSObject, ObservableObject {
    static let shared = RTMPStreamManager()

    @Published var state: StreamingState = .idle
    @Published var statistics: StreamingStatistics = StreamingStatistics()
    @Published var isStreaming: Bool = false

    var configuration: StreamConfiguration = StreamConfiguration()

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var audioOutput: AVCaptureAudioDataOutput?

    private var compressionSession: VTCompressionSession?
    private var audioConverter: AVAudioConverter?

    private var outputStream: OutputStream?
    private var inputStream: InputStream?

    private var streamStartTime: Date?
    private var frameCount: Int = 0

    private let streamQueue = DispatchQueue(label: "com.videoeditor.stream", qos: .userInteractive)
    private let encoderQueue = DispatchQueue(label: "com.videoeditor.encoder", qos: .userInteractive)

    // MARK: - 初始化

    override init() {
        super.init()
        setupNotifications()
    }

    private func setupNotifications() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        #endif
    }

    @objc private func handleInterruption(_ notification: Notification) {
        // 处理音频中断
    }

    // MARK: - 推流控制

    /// 开始推流
    func startStreaming(with config: StreamConfiguration, completion: @escaping (Result<Void, Error>) -> Void) {
        configuration = config
        state = .connecting

        streamQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                // 设置采集
                try self.setupCaptureSession()

                // 设置编码器
                try self.setupVideoEncoder()

                // 连接推流服务器
                try self.connectToServer()

                self.captureSession?.startRunning()
                self.streamStartTime = Date()

                DispatchQueue.main.async {
                    self.state = .streaming
                    self.isStreaming = true
                    completion(.success(()))
                }

                // 开始统计更新
                self.startStatisticsUpdate()

            } catch {
                DispatchQueue.main.async {
                    self.state = .error(error)
                    completion(.failure(error))
                }
            }
        }
    }

    /// 停止推流
    func stopStreaming() {
        streamQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.closeConnection()

            DispatchQueue.main.async {
                self?.state = .stopped
                self?.isStreaming = false
                self?.statistics = StreamingStatistics()
            }
        }
    }

    /// 暂停推流
    func pauseStreaming() {
        // 发送黑屏帧或静音
    }

    /// 恢复推流
    func resumeStreaming() {
        // 恢复正常推流
    }

    // MARK: - 采集设置

    private func setupCaptureSession() throws {
        let session = AVCaptureSession()

        // 设置分辨率
        session.sessionPreset = getSessionPreset()

        // 添加视频输入
        #if canImport(AVFoundation)
        if let videoDevice = AVCaptureDevice.default(for: .video) {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }
        }

        // 添加音频输入
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }
        #endif

        // 添加视频输出
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: encoderQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        self.videoOutput = videoOutput

        // 添加音频输出
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: encoderQueue)
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }
        self.audioOutput = audioOutput

        self.captureSession = session
    }

    private func getSessionPreset() -> AVCaptureSession.Preset {
        switch (configuration.videoWidth, configuration.videoHeight) {
        case (_, 2160): return .hd4K3840x2160
        case (_, 1080): return .hd1920x1080
        case (_, 720): return .hd1280x720
        default: return .hd1920x1080
        }
    }

    // MARK: - 视频编码

    private func setupVideoEncoder() throws {
        var session: VTCompressionSession?

        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(configuration.videoWidth),
            height: Int32(configuration.videoHeight),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: [
                kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder: configuration.enableHardwareEncoder
            ] as CFDictionary,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )

        guard status == noErr, let compressionSession = session else {
            throw NSError(domain: "EncoderError", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "无法创建视频编码器"])
        }

        // 配置编码器
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_High_AutoLevel)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_AverageBitRate, value: configuration.videoBitrate as CFNumber)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: configuration.frameRate * configuration.keyframeInterval as CFNumber)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: configuration.frameRate as CFNumber)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)

        VTCompressionSessionPrepareToEncodeFrames(compressionSession)

        self.compressionSession = compressionSession
    }

    private func encodeVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let compressionSession = compressionSession,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)

        var flags: VTEncodeInfoFlags = []

        let status = VTCompressionSessionEncodeFrame(
            compressionSession,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: duration,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags
        )

        if status == noErr {
            frameCount += 1
        } else {
            DispatchQueue.main.async {
                self.statistics.droppedFrames += 1
            }
        }
    }

    // MARK: - 网络连接

    private func connectToServer() throws {
        let urlString = configuration.fullStreamURL
        guard !urlString.isEmpty else {
            throw NSError(domain: "StreamError", code: -1, userInfo: [NSLocalizedDescriptionKey: "推流地址为空"])
        }

        // 解析URL
        guard let url = URL(string: urlString),
              let host = url.host else {
            throw NSError(domain: "StreamError", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的推流地址"])
        }

        let port = url.port ?? configuration.protocol.defaultPort

        // 创建Socket连接
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(
            kCFAllocatorDefault,
            host as CFString,
            UInt32(port),
            &readStream,
            &writeStream
        )

        guard let inputStream = readStream?.takeRetainedValue() as InputStream?,
              let outputStream = writeStream?.takeRetainedValue() as OutputStream? else {
            throw NSError(domain: "StreamError", code: -3, userInfo: [NSLocalizedDescriptionKey: "无法创建网络连接"])
        }

        // 配置SSL (如果是RTMPS)
        if configuration.protocol == .rtmps {
            inputStream.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
            outputStream.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
        }

        inputStream.open()
        outputStream.open()

        self.inputStream = inputStream
        self.outputStream = outputStream

        // RTMP握手
        try performRTMPHandshake()
    }

    private func performRTMPHandshake() throws {
        // RTMP C0+C1
        var c0c1 = Data(count: 1537)
        c0c1[0] = 3 // RTMP版本

        // 时间戳
        let timestamp = UInt32(Date().timeIntervalSince1970)
        c0c1[1] = UInt8((timestamp >> 24) & 0xFF)
        c0c1[2] = UInt8((timestamp >> 16) & 0xFF)
        c0c1[3] = UInt8((timestamp >> 8) & 0xFF)
        c0c1[4] = UInt8(timestamp & 0xFF)

        // 零填充
        c0c1[5] = 0
        c0c1[6] = 0
        c0c1[7] = 0
        c0c1[8] = 0

        // 随机数据
        for i in 9..<1537 {
            c0c1[i] = UInt8.random(in: 0...255)
        }

        _ = c0c1.withUnsafeBytes { ptr in
            outputStream?.write(ptr.bindMemory(to: UInt8.self).baseAddress!, maxLength: c0c1.count)
        }

        // 等待S0+S1+S2响应
        // 这里需要完整的RTMP协议实现
    }

    private func sendRTMPData(_ data: Data) {
        _ = data.withUnsafeBytes { ptr in
            outputStream?.write(ptr.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
        }
    }

    private func closeConnection() {
        inputStream?.close()
        outputStream?.close()
        inputStream = nil
        outputStream = nil

        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
        compressionSession = nil
    }

    // MARK: - 统计更新

    private func startStatisticsUpdate() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isStreaming else {
                timer.invalidate()
                return
            }

            self.updateStatistics()
        }
    }

    private func updateStatistics() {
        guard let startTime = streamStartTime else { return }

        DispatchQueue.main.async {
            self.statistics.duration = Date().timeIntervalSince(startTime)
            self.statistics.sentFrames = self.frameCount
            self.statistics.fps = Double(self.frameCount) / self.statistics.duration
            self.statistics.currentBitrate = self.configuration.videoBitrate
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension RTMPStreamManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == videoOutput {
            encodeVideoFrame(sampleBuffer)
        } else if output == audioOutput {
            encodeAudioFrame(sampleBuffer)
        }
    }

    private func encodeAudioFrame(_ sampleBuffer: CMSampleBuffer) {
        // 音频编码和发送
    }
}

// MARK: - 虚拟摄像头

/// 虚拟摄像头管理器
class VirtualCameraManager: ObservableObject {
    static let shared = VirtualCameraManager()

    @Published var isActive: Bool = false
    @Published var currentSource: VideoSource = .none
    @Published var appliedFilters: [LiveFilter] = []

    enum VideoSource {
        case none
        case camera
        case screen
        case window(WindowInfo)
        case composition
        case mediaFile(URL)
    }

    struct WindowInfo {
        var id: CGWindowID
        var title: String
        var ownerName: String
    }

    private var outputPixelBuffer: CVPixelBuffer?
    private var ciContext: CIContext?
    private var videoComposition: AVVideoComposition?

    init() {
        setupCIContext()
    }

    private func setupCIContext() {
        ciContext = CIContext(options: [.useSoftwareRenderer: false])
    }

    /// 启动虚拟摄像头
    func startVirtualCamera(source: VideoSource) {
        currentSource = source
        isActive = true

        switch source {
        case .camera:
            startCameraCapture()
        case .screen:
            startScreenCapture()
        case .window(let info):
            startWindowCapture(windowId: info.id)
        case .composition:
            startCompositionOutput()
        case .mediaFile(let url):
            startMediaFileOutput(url: url)
        case .none:
            break
        }
    }

    /// 停止虚拟摄像头
    func stopVirtualCamera() {
        isActive = false
        currentSource = .none
    }

    private func startCameraCapture() {
        // 从摄像头采集
    }

    private func startScreenCapture() {
        #if canImport(AppKit)
        // macOS屏幕采集
        #endif
    }

    private func startWindowCapture(windowId: CGWindowID) {
        // 窗口采集
    }

    private func startCompositionOutput() {
        // 从项目合成输出
    }

    private func startMediaFileOutput(url: URL) {
        // 播放媒体文件
    }

    /// 添加滤镜
    func addFilter(_ filter: LiveFilter) {
        appliedFilters.append(filter)
    }

    /// 移除滤镜
    func removeFilter(_ filter: LiveFilter) {
        appliedFilters.removeAll { $0.id == filter.id }
    }

    /// 处理帧
    func processFrame(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        guard let context = ciContext else { return pixelBuffer }

        var image = CIImage(cvPixelBuffer: pixelBuffer)

        // 应用滤镜
        for filter in appliedFilters where filter.isEnabled {
            if let processedImage = filter.apply(to: image) {
                image = processedImage
            }
        }

        // 渲染回像素缓冲区
        context.render(image, to: pixelBuffer)

        return pixelBuffer
    }

    /// 获取可用窗口列表
    func getAvailableWindows() -> [WindowInfo] {
        var windows: [WindowInfo] = []

        #if canImport(AppKit)
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
            for windowInfo in windowList {
                guard let windowId = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                      let title = windowInfo[kCGWindowName as String] as? String,
                      let ownerName = windowInfo[kCGWindowOwnerName as String] as? String else {
                    continue
                }

                windows.append(WindowInfo(id: windowId, title: title, ownerName: ownerName))
            }
        }
        #endif

        return windows
    }
}

// MARK: - 实时滤镜

/// 实时滤镜
class LiveFilter: Identifiable, ObservableObject {
    let id: UUID
    var name: String
    var type: FilterType
    @Published var isEnabled: Bool = true
    @Published var parameters: [String: Any] = [:]

    enum FilterType: String, CaseIterable {
        case beauty = "美颜"
        case colorCorrection = "调色"
        case blur = "模糊"
        case sharpen = "锐化"
        case vignette = "暗角"
        case chromaKey = "抠像"
        case lut = "LUT"
        case overlay = "叠加"
        case border = "边框"
        case mosaic = "马赛克"
        case cartoon = "卡通"
        case vintage = "复古"
        case blackWhite = "黑白"
        case sepia = "怀旧"
        case custom = "自定义"
    }

    init(name: String, type: FilterType) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.parameters = getDefaultParameters(for: type)
    }

    private func getDefaultParameters(for type: FilterType) -> [String: Any] {
        switch type {
        case .beauty:
            return ["smoothing": 0.5, "whitening": 0.3, "thinFace": 0.2, "bigEyes": 0.2]
        case .colorCorrection:
            return ["brightness": 0.0, "contrast": 1.0, "saturation": 1.0, "temperature": 0.0]
        case .blur:
            return ["radius": 10.0]
        case .sharpen:
            return ["intensity": 0.5]
        case .vignette:
            return ["intensity": 0.5, "radius": 1.0]
        case .chromaKey:
            return ["color": [0.0, 1.0, 0.0], "threshold": 0.4, "smoothness": 0.1]
        case .lut:
            return ["lutName": "", "intensity": 1.0]
        case .overlay:
            return ["image": "", "opacity": 0.5, "blendMode": "normal"]
        case .mosaic:
            return ["size": 10.0, "rect": [0.0, 0.0, 0.0, 0.0]]
        default:
            return [:]
        }
    }

    /// 应用滤镜
    func apply(to image: CIImage) -> CIImage? {
        guard isEnabled else { return image }

        switch type {
        case .beauty:
            return applyBeautyFilter(to: image)
        case .colorCorrection:
            return applyColorCorrection(to: image)
        case .blur:
            return applyBlur(to: image)
        case .sharpen:
            return applySharpen(to: image)
        case .vignette:
            return applyVignette(to: image)
        case .chromaKey:
            return applyChromaKey(to: image)
        case .blackWhite:
            return applyBlackWhite(to: image)
        case .sepia:
            return applySepia(to: image)
        case .cartoon:
            return applyCartoon(to: image)
        case .vintage:
            return applyVintage(to: image)
        default:
            return image
        }
    }

    private func applyBeautyFilter(to image: CIImage) -> CIImage? {
        let smoothing = parameters["smoothing"] as? Double ?? 0.5

        // 简化的美颜效果：使用模糊和混合
        guard let blurred = CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: image,
            kCIInputRadiusKey: smoothing * 10
        ])?.outputImage else { return image }

        // 高通滤波保留细节
        guard let highPass = CIFilter(name: "CISourceOverCompositing", parameters: [
            kCIInputImageKey: image,
            kCIInputBackgroundImageKey: blurred
        ])?.outputImage else { return image }

        return highPass
    }

    private func applyColorCorrection(to image: CIImage) -> CIImage? {
        let brightness = parameters["brightness"] as? Double ?? 0.0
        let contrast = parameters["contrast"] as? Double ?? 1.0
        let saturation = parameters["saturation"] as? Double ?? 1.0

        return CIFilter(name: "CIColorControls", parameters: [
            kCIInputImageKey: image,
            kCIInputBrightnessKey: brightness,
            kCIInputContrastKey: contrast,
            kCIInputSaturationKey: saturation
        ])?.outputImage
    }

    private func applyBlur(to image: CIImage) -> CIImage? {
        let radius = parameters["radius"] as? Double ?? 10.0

        return CIFilter(name: "CIGaussianBlur", parameters: [
            kCIInputImageKey: image,
            kCIInputRadiusKey: radius
        ])?.outputImage
    }

    private func applySharpen(to image: CIImage) -> CIImage? {
        let intensity = parameters["intensity"] as? Double ?? 0.5

        return CIFilter(name: "CISharpenLuminance", parameters: [
            kCIInputImageKey: image,
            kCIInputSharpnessKey: intensity
        ])?.outputImage
    }

    private func applyVignette(to image: CIImage) -> CIImage? {
        let intensity = parameters["intensity"] as? Double ?? 0.5
        let radius = parameters["radius"] as? Double ?? 1.0

        return CIFilter(name: "CIVignette", parameters: [
            kCIInputImageKey: image,
            kCIInputIntensityKey: intensity,
            kCIInputRadiusKey: radius
        ])?.outputImage
    }

    private func applyChromaKey(to image: CIImage) -> CIImage? {
        // 简化的绿幕抠像
        let threshold = parameters["threshold"] as? Double ?? 0.4

        guard let colorCube = createChromaKeyColorCube(threshold: Float(threshold)) else {
            return image
        }

        return CIFilter(name: "CIColorCube", parameters: [
            kCIInputImageKey: image,
            "inputCubeDimension": 64,
            "inputCubeData": colorCube
        ])?.outputImage
    }

    private func createChromaKeyColorCube(threshold: Float) -> Data? {
        let size = 64
        var cubeData = [Float](repeating: 0, count: size * size * size * 4)

        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let red = Float(r) / Float(size - 1)
                    let green = Float(g) / Float(size - 1)
                    let blue = Float(b) / Float(size - 1)

                    // 检测绿色
                    let isGreen = green > red + threshold && green > blue + threshold

                    let alpha: Float = isGreen ? 0.0 : 1.0

                    let offset = (b * size * size + g * size + r) * 4
                    cubeData[offset] = red * alpha
                    cubeData[offset + 1] = green * alpha
                    cubeData[offset + 2] = blue * alpha
                    cubeData[offset + 3] = alpha
                }
            }
        }

        return Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size)
    }

    private func applyBlackWhite(to image: CIImage) -> CIImage? {
        return CIFilter(name: "CIPhotoEffectMono", parameters: [
            kCIInputImageKey: image
        ])?.outputImage
    }

    private func applySepia(to image: CIImage) -> CIImage? {
        return CIFilter(name: "CISepiaTone", parameters: [
            kCIInputImageKey: image,
            kCIInputIntensityKey: 0.8
        ])?.outputImage
    }

    private func applyCartoon(to image: CIImage) -> CIImage? {
        // 卡通效果：边缘检测 + 色彩量化
        guard let edges = CIFilter(name: "CIEdges", parameters: [
            kCIInputImageKey: image,
            kCIInputIntensityKey: 1.0
        ])?.outputImage else { return image }

        guard let posterized = CIFilter(name: "CIColorPosterize", parameters: [
            kCIInputImageKey: image,
            "inputLevels": 6
        ])?.outputImage else { return image }

        return CIFilter(name: "CIMultiplyBlendMode", parameters: [
            kCIInputImageKey: edges,
            kCIInputBackgroundImageKey: posterized
        ])?.outputImage
    }

    private func applyVintage(to image: CIImage) -> CIImage? {
        return CIFilter(name: "CIPhotoEffectInstant", parameters: [
            kCIInputImageKey: image
        ])?.outputImage
    }
}

// MARK: - 直播录制

/// 直播录制管理器
class LiveRecordingManager: ObservableObject {
    static let shared = LiveRecordingManager()

    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingFileSize: Int64 = 0
    @Published var recordingURL: URL?

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var recordingStartTime: CMTime?
    private var frameCount: Int = 0

    private let recordingQueue = DispatchQueue(label: "com.videoeditor.recording", qos: .userInitiated)

    /// 开始录制
    func startRecording(to url: URL, width: Int, height: Int, frameRate: Int) throws {
        // 创建AssetWriter
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        // 视频输入
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoMaxKeyFrameIntervalKey: frameRate * 2
            ]
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        // 音频输入
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192000
        ]

        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true

        writer.add(videoInput)
        writer.add(audioInput)

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "RecordingError", code: -1)
        }

        self.assetWriter = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.pixelBufferAdaptor = adaptor
        self.recordingURL = url
        self.isRecording = true
        self.frameCount = 0

        // 启动统计更新
        startDurationUpdate()
    }

    /// 停止录制
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }

        isRecording = false

        recordingQueue.async { [weak self] in
            self?.videoInput?.markAsFinished()
            self?.audioInput?.markAsFinished()

            self?.assetWriter?.finishWriting {
                DispatchQueue.main.async {
                    completion(self?.recordingURL)
                    self?.cleanup()
                }
            }
        }
    }

    /// 添加视频帧
    func appendVideoFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard isRecording,
              let adaptor = pixelBufferAdaptor,
              let input = videoInput,
              input.isReadyForMoreMediaData else {
            return
        }

        if recordingStartTime == nil {
            recordingStartTime = presentationTime
            assetWriter?.startSession(atSourceTime: presentationTime)
        }

        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        frameCount += 1
    }

    /// 添加音频样本
    func appendAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let input = audioInput,
              input.isReadyForMoreMediaData else {
            return
        }

        input.append(sampleBuffer)
    }

    private func startDurationUpdate() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, self.isRecording else {
                timer.invalidate()
                return
            }

            if let url = self.recordingURL,
               let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                DispatchQueue.main.async {
                    self.recordingFileSize = size
                }
            }
        }
    }

    private func cleanup() {
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        recordingStartTime = nil
        recordingDuration = 0
        recordingFileSize = 0
    }
}

// MARK: - 直播场景

/// 直播场景
class LiveScene: Identifiable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var sources: [LiveSource] = []
    @Published var isActive: Bool = false

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

/// 直播源
class LiveSource: Identifiable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var type: SourceType
    @Published var frame: CGRect
    @Published var isVisible: Bool = true
    @Published var opacity: Double = 1.0
    @Published var zIndex: Int = 0
    @Published var filters: [LiveFilter] = []
    @Published var url: URL?

    enum SourceType: String, CaseIterable {
        case camera = "摄像头"
        case screen = "屏幕"
        case window = "窗口"
        case image = "图片"
        case video = "视频"
        case text = "文字"
        case browser = "网页"
        case ndi = "NDI"
        case game = "游戏"
    }

    init(name: String, type: SourceType) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }
}

/// 直播场景管理器
class LiveSceneManager: ObservableObject {
    static let shared = LiveSceneManager()

    @Published var scenes: [LiveScene] = []
    @Published var currentScene: LiveScene?
    @Published var transitionType: TransitionType = .cut
    @Published var transitionDuration: Double = 0.5

    enum TransitionType: String, CaseIterable {
        case cut = "直切"
        case fade = "淡入淡出"
        case slide = "滑动"
        case swipe = "擦除"
        case zoom = "缩放"
    }

    init() {
        createDefaultScene()
    }

    private func createDefaultScene() {
        let scene = LiveScene(name: "场景 1")
        scenes.append(scene)
        currentScene = scene
    }

    /// 创建场景
    func createScene(name: String) -> LiveScene {
        let scene = LiveScene(name: name)
        scenes.append(scene)
        return scene
    }

    /// 切换场景
    func switchToScene(_ scene: LiveScene, animated: Bool = true) {
        guard scene.id != currentScene?.id else { return }

        if animated {
            performTransition(to: scene)
        } else {
            currentScene?.isActive = false
            currentScene = scene
            scene.isActive = true
        }
    }

    private func performTransition(to scene: LiveScene) {
        // 执行转场动画
        let oldScene = currentScene

        // 简化的转场
        DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration) {
            oldScene?.isActive = false
            self.currentScene = scene
            scene.isActive = true
        }
    }

    /// 添加源到场景
    func addSource(_ source: LiveSource, to scene: LiveScene) {
        source.zIndex = scene.sources.count
        scene.sources.append(source)
    }

    /// 从场景移除源
    func removeSource(_ source: LiveSource, from scene: LiveScene) {
        scene.sources.removeAll { $0.id == source.id }
    }

    /// 删除场景
    func deleteScene(_ scene: LiveScene) {
        guard scenes.count > 1 else { return }

        scenes.removeAll { $0.id == scene.id }

        if currentScene?.id == scene.id {
            currentScene = scenes.first
        }
    }
}
