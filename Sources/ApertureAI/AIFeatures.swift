import Foundation
import AVFoundation
import Vision
import NaturalLanguage
import Speech
import CoreImage

// MARK: - 自动字幕（语音识别）

/// 语音识别服务
class SpeechRecognitionService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Float = 0
    @Published var recognizedText: String = ""

    private var recognitionTask: SFSpeechRecognitionTask?

    /// 支持的语言
    enum Language: String, CaseIterable {
        case chinese = "zh-CN"
        case english = "en-US"
        case japanese = "ja-JP"
        case korean = "ko-KR"
        case french = "fr-FR"
        case german = "de-DE"
        case spanish = "es-ES"

        var displayName: String {
            switch self {
            case .chinese: return "中文"
            case .english: return "英语"
            case .japanese: return "日语"
            case .korean: return "韩语"
            case .french: return "法语"
            case .german: return "德语"
            case .spanish: return "西班牙语"
            }
        }

        var locale: Locale {
            Locale(identifier: rawValue)
        }
    }

    /// 请求语音识别权限
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// 从视频生成字幕
    func generateSubtitles(
        from asset: AVAsset,
        language: Language = .chinese
    ) async throws -> [Subtitle] {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw AIError.notAuthorized
        }

        guard let recognizer = SFSpeechRecognizer(locale: language.locale),
              recognizer.isAvailable else {
            throw AIError.recognizerUnavailable
        }

        await MainActor.run {
            isProcessing = true
            progress = 0
        }

        // 提取音频
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        try await AudioSeparator.separateAudio(from: asset, outputURL: audioURL)

        await MainActor.run {
            progress = 0.2
        }

        // 创建识别请求
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        // 执行识别
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result = result, result.isFinal {
                    continuation.resume(returning: result)
                }
            }
        }

        await MainActor.run {
            progress = 0.8
        }

        // 转换为字幕
        var subtitles: [Subtitle] = []
        let segments = result.bestTranscription.segments

        for segment in segments {
            let subtitle = Subtitle(
                text: segment.substring,
                timeRange: CMTimeRange(
                    start: CMTime(seconds: segment.timestamp, preferredTimescale: 600),
                    duration: CMTime(seconds: segment.duration, preferredTimescale: 600)
                )
            )
            subtitles.append(subtitle)
        }

        // 合并短字幕
        subtitles = mergeShortSubtitles(subtitles, minDuration: 1.0)

        // 清理临时文件
        try? FileManager.default.removeItem(at: audioURL)

        await MainActor.run {
            isProcessing = false
            progress = 1.0
        }

        return subtitles
    }

    /// 合并短字幕
    private func mergeShortSubtitles(_ subtitles: [Subtitle], minDuration: Double) -> [Subtitle] {
        var merged: [Subtitle] = []
        var currentText = ""
        var currentStart: CMTime?
        var currentEnd: CMTime = .zero

        for subtitle in subtitles {
            let duration = CMTimeGetSeconds(subtitle.timeRange.duration)

            if currentStart == nil {
                currentStart = subtitle.timeRange.start
            }

            currentText += (currentText.isEmpty ? "" : " ") + subtitle.text
            currentEnd = subtitle.timeRange.end

            let totalDuration = CMTimeGetSeconds(CMTimeSubtract(currentEnd, currentStart!))

            if totalDuration >= minDuration || subtitle == subtitles.last {
                let mergedSubtitle = Subtitle(
                    text: currentText,
                    timeRange: CMTimeRange(start: currentStart!, end: currentEnd)
                )
                merged.append(mergedSubtitle)
                currentText = ""
                currentStart = nil
            }
        }

        return merged
    }

    /// 取消识别
    func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
        isProcessing = false
    }
}

// MARK: - 智能抠图（人像分割）

/// 人像分割服务
class PersonSegmentationService {

    /// 分割人像
    func segmentPerson(from image: CGImage) async throws -> CGImage? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])

                    guard let result = request.results?.first else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let maskBuffer = result.pixelBuffer

                    // 将蒙版转换为 CGImage
                    let ciImage = CIImage(cvPixelBuffer: maskBuffer)
                    let context = CIContext()

                    if let cgMask = context.createCGImage(ciImage, from: ciImage.extent) {
                        continuation.resume(returning: cgMask)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 创建 CIFilter 用于实时处理
    func createSegmentationFilter() -> CIFilter? {
        // 使用 Vision 框架的人像分割
        return nil  // 需要通过 VNGeneratePersonSegmentationRequest 处理每一帧
    }

    /// 处理视频帧
    func processVideoFrame(_ pixelBuffer: CVPixelBuffer) async throws -> CVPixelBuffer? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced  // 平衡质量和速度
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        return request.results?.first?.pixelBuffer
    }

    /// 应用抠图效果
    func applySegmentation(
        foreground: CIImage,
        background: CIImage,
        mask: CIImage
    ) -> CIImage {
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = foreground
        blendFilter.backgroundImage = background
        blendFilter.maskImage = mask

        return blendFilter.outputImage ?? foreground
    }
}

// MARK: - 场景检测

/// 场景检测服务
class SceneDetectionService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Float = 0
    @Published var detectedScenes: [DetectedScene] = []

    /// 检测到的场景
    struct DetectedScene: Identifiable {
        let id = UUID()
        var startTime: CMTime
        var endTime: CMTime
        var thumbnail: CGImage?
        var description: String?
        var confidence: Float

        var duration: CMTime {
            CMTimeSubtract(endTime, startTime)
        }
    }

    /// 场景检测灵敏度
    enum Sensitivity: Float, CaseIterable {
        case low = 0.3
        case medium = 0.5
        case high = 0.7

        var displayName: String {
            switch self {
            case .low: return "低"
            case .medium: return "中"
            case .high: return "高"
            }
        }
    }

    /// 检测场景变化
    func detectScenes(
        in asset: AVAsset,
        sensitivity: Sensitivity = .medium
    ) async throws -> [DetectedScene] {
        await MainActor.run {
            isProcessing = true
            progress = 0
            detectedScenes = []
        }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        // 每秒采样一帧
        let sampleRate: Double = 1.0
        let totalSamples = Int(durationSeconds / sampleRate)

        var histograms: [(time: CMTime, histogram: [Float])] = []
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 90)  // 小尺寸加速处理

        // 生成帧并计算直方图
        for i in 0..<totalSamples {
            let time = CMTime(seconds: Double(i) * sampleRate, preferredTimescale: 600)

            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let histogram = calculateHistogram(for: cgImage)
                histograms.append((time, histogram))
            } catch {
                continue
            }

            await MainActor.run {
                progress = Float(i) / Float(totalSamples) * 0.8
            }
        }

        // 检测场景变化
        var scenes: [DetectedScene] = []
        var currentSceneStart = CMTime.zero
        var previousHistogram: [Float]?

        for (time, histogram) in histograms {
            if let prev = previousHistogram {
                let diff = histogramDifference(prev, histogram)

                if diff > sensitivity.rawValue {
                    // 检测到场景变化
                    let thumbnail = try? generator.copyCGImage(at: currentSceneStart, actualTime: nil)

                    let scene = DetectedScene(
                        startTime: currentSceneStart,
                        endTime: time,
                        thumbnail: thumbnail,
                        description: nil,
                        confidence: diff
                    )
                    scenes.append(scene)

                    currentSceneStart = time
                }
            }

            previousHistogram = histogram
        }

        // 添加最后一个场景
        let lastThumbnail = try? generator.copyCGImage(at: currentSceneStart, actualTime: nil)
        let lastScene = DetectedScene(
            startTime: currentSceneStart,
            endTime: duration,
            thumbnail: lastThumbnail,
            description: nil,
            confidence: 1.0
        )
        scenes.append(lastScene)

        await MainActor.run {
            isProcessing = false
            progress = 1.0
            detectedScenes = scenes
        }

        return scenes
    }

    /// 计算图像直方图
    private func calculateHistogram(for image: CGImage) -> [Float] {
        let width = image.width
        let height = image.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return [] }

        let pixelData = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // 简化的直方图：RGB 各 16 个 bin
        var histogram = [Float](repeating: 0, count: 48)

        for i in 0..<(width * height) {
            let r = Int(pixelData[i * 4]) / 16
            let g = Int(pixelData[i * 4 + 1]) / 16
            let b = Int(pixelData[i * 4 + 2]) / 16

            histogram[r] += 1
            histogram[16 + g] += 1
            histogram[32 + b] += 1
        }

        // 归一化
        let total = Float(width * height)
        return histogram.map { $0 / total }
    }

    /// 计算直方图差异
    private func histogramDifference(_ h1: [Float], _ h2: [Float]) -> Float {
        guard h1.count == h2.count else { return 1 }

        var diff: Float = 0
        for i in 0..<h1.count {
            diff += abs(h1[i] - h2[i])
        }

        return diff / Float(h1.count)
    }
}

// MARK: - 人脸检测与追踪

/// 人脸检测服务
class FaceDetectionService {

    /// 检测到的人脸
    struct DetectedFace: Identifiable {
        let id = UUID()
        var boundingBox: CGRect  // 归一化坐标
        var landmarks: VNFaceLandmarks2D?
        var confidence: Float
        var roll: CGFloat?
        var yaw: CGFloat?
    }

    /// 检测人脸
    func detectFaces(in image: CGImage) async throws -> [DetectedFace] {
        let request = VNDetectFaceLandmarksRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])

                    let faces = request.results?.map { observation -> DetectedFace in
                        DetectedFace(
                            boundingBox: observation.boundingBox,
                            landmarks: observation.landmarks,
                            confidence: observation.confidence,
                            roll: observation.roll.map { CGFloat($0.doubleValue) },
                            yaw: observation.yaw.map { CGFloat($0.doubleValue) }
                        )
                    } ?? []

                    continuation.resume(returning: faces)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 人脸追踪（用于视频）
    func trackFaces(
        in asset: AVAsset,
        onFrame: @escaping (CMTime, [DetectedFace]) -> Void
    ) async throws {
        let duration = try await asset.load(.duration)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let frameRate: Double = 10  // 每秒10帧
        let totalFrames = Int(CMTimeGetSeconds(duration) * frameRate)

        for i in 0..<totalFrames {
            let time = CMTime(seconds: Double(i) / frameRate, preferredTimescale: 600)

            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let faces = try await detectFaces(in: cgImage)
                onFrame(time, faces)
            } catch {
                continue
            }
        }
    }
}

// MARK: - 物体检测

/// 物体检测服务
class ObjectDetectionService {

    /// 检测到的物体
    struct DetectedObject: Identifiable {
        let id = UUID()
        var label: String
        var confidence: Float
        var boundingBox: CGRect
    }

    /// 检测物体
    func detectObjects(in image: CGImage) async throws -> [DetectedObject] {
        let request = VNRecognizeAnimalsRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])

                    let objects = request.results?.flatMap { observation -> [DetectedObject] in
                        observation.labels.map { label in
                            DetectedObject(
                                label: label.identifier,
                                confidence: label.confidence,
                                boundingBox: observation.boundingBox
                            )
                        }
                    } ?? []

                    continuation.resume(returning: objects)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 检测文字 (OCR)
    func detectText(in image: CGImage) async throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])

                    let texts = request.results?.compactMap { observation -> String? in
                        observation.topCandidates(1).first?.string
                    } ?? []

                    continuation.resume(returning: texts)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - 智能剪辑建议

/// 智能剪辑建议服务
class SmartEditSuggestionService {

    /// 剪辑建议
    struct EditSuggestion: Identifiable {
        let id = UUID()
        var type: SuggestionType
        var timeRange: CMTimeRange
        var description: String
        var confidence: Float

        enum SuggestionType: String {
            case trim = "裁剪"
            case highlight = "精彩片段"
            case transition = "添加转场"
            case filter = "推荐滤镜"
            case music = "配乐建议"
            case text = "添加文字"
        }
    }

    /// 分析视频并生成建议
    func analyzAndSuggest(asset: AVAsset) async throws -> [EditSuggestion] {
        var suggestions: [EditSuggestion] = []

        // 1. 场景检测
        let sceneService = SceneDetectionService()
        let scenes = try await sceneService.detectScenes(in: asset, sensitivity: .medium)

        // 为每个场景转换点添加转场建议
        for i in 1..<scenes.count {
            let scene = scenes[i]
            suggestions.append(EditSuggestion(
                type: .transition,
                timeRange: CMTimeRange(start: scene.startTime, duration: CMTime(seconds: 1, preferredTimescale: 600)),
                description: "建议在此处添加转场效果",
                confidence: scene.confidence
            ))
        }

        // 2. 分析音频高潮点
        let audioHighlights = try await analyzeAudioHighlights(in: asset)
        for highlight in audioHighlights {
            suggestions.append(EditSuggestion(
                type: .highlight,
                timeRange: highlight.timeRange,
                description: "音频高潮点，可作为精彩片段",
                confidence: highlight.confidence
            ))
        }

        // 3. 检测低质量片段（模糊、抖动）
        let lowQualitySegments = try await detectLowQualitySegments(in: asset)
        for segment in lowQualitySegments {
            suggestions.append(EditSuggestion(
                type: .trim,
                timeRange: segment.timeRange,
                description: "建议裁剪此低质量片段",
                confidence: segment.confidence
            ))
        }

        return suggestions.sorted { $0.confidence > $1.confidence }
    }

    /// 分析音频高潮点
    private func analyzeAudioHighlights(in asset: AVAsset) async throws -> [(timeRange: CMTimeRange, confidence: Float)] {
        // 简化实现：通过音量变化检测高潮
        let waveform = try await AudioEngine.generateWaveform(from: asset, samplesPerSecond: 10)

        var highlights: [(timeRange: CMTimeRange, confidence: Float)] = []
        let threshold: Float = 0.7

        var inHighlight = false
        var highlightStart: Int = 0

        for (i, sample) in waveform.enumerated() {
            if sample > threshold && !inHighlight {
                inHighlight = true
                highlightStart = i
            } else if sample < threshold * 0.8 && inHighlight {
                inHighlight = false

                let startTime = CMTime(seconds: Double(highlightStart) / 10.0, preferredTimescale: 600)
                let endTime = CMTime(seconds: Double(i) / 10.0, preferredTimescale: 600)

                highlights.append((
                    timeRange: CMTimeRange(start: startTime, end: endTime),
                    confidence: sample
                ))
            }
        }

        return highlights
    }

    /// 检测低质量片段
    private func detectLowQualitySegments(in asset: AVAsset) async throws -> [(timeRange: CMTimeRange, confidence: Float)] {
        // 简化实现
        return []
    }
}

// MARK: - AI 错误

enum AIError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "未获得授权"
        case .recognizerUnavailable: return "识别服务不可用"
        case .processingFailed: return "处理失败"
        }
    }
}
