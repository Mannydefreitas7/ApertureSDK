//
//  ImportExportEnhanced.swift
//  VideoEditor
//
//  导入导出增强模块 - ProRes、HEVC、XML/EDL、直接发布
//

import Foundation
import AVFoundation
import VideoToolbox
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 导出预设

/// 导出预设类型
enum ExportPresetType: String, CaseIterable, Codable {
    case h264_1080p = "H.264 1080p"
    case h264_4k = "H.264 4K"
    case h265_1080p = "HEVC 1080p"
    case h265_4k = "HEVC 4K"
    case prores422 = "ProRes 422"
    case prores422hq = "ProRes 422 HQ"
    case prores4444 = "ProRes 4444"
    case proresRaw = "ProRes RAW"
    case gif = "GIF"
    case audioOnly = "仅音频"
    case youtube = "YouTube"
    case tiktok = "抖音/TikTok"
    case instagram = "Instagram"
    case twitter = "Twitter"
    case bilibili = "哔哩哔哩"
    case wechat = "微信视频号"
    case custom = "自定义"

    var settings: ExportSettings {
        switch self {
        case .h264_1080p:
            return ExportSettings(
                videoCodec: .h264,
                width: 1920, height: 1080,
                frameRate: 30, videoBitRate: 10_000_000,
                audioCodec: .aac, audioBitRate: 192_000,
                container: .mp4
            )
        case .h264_4k:
            return ExportSettings(
                videoCodec: .h264,
                width: 3840, height: 2160,
                frameRate: 30, videoBitRate: 40_000_000,
                audioCodec: .aac, audioBitRate: 320_000,
                container: .mp4
            )
        case .h265_1080p:
            return ExportSettings(
                videoCodec: .hevc,
                width: 1920, height: 1080,
                frameRate: 30, videoBitRate: 6_000_000,
                audioCodec: .aac, audioBitRate: 192_000,
                container: .mp4
            )
        case .h265_4k:
            return ExportSettings(
                videoCodec: .hevc,
                width: 3840, height: 2160,
                frameRate: 30, videoBitRate: 20_000_000,
                audioCodec: .aac, audioBitRate: 320_000,
                container: .mp4
            )
        case .prores422:
            return ExportSettings(
                videoCodec: .prores422,
                width: 1920, height: 1080,
                frameRate: 30, videoBitRate: 147_000_000,
                audioCodec: .pcm, audioBitRate: 1_536_000,
                container: .mov
            )
        case .prores422hq:
            return ExportSettings(
                videoCodec: .prores422hq,
                width: 1920, height: 1080,
                frameRate: 30, videoBitRate: 220_000_000,
                audioCodec: .pcm, audioBitRate: 1_536_000,
                container: .mov
            )
        case .prores4444:
            return ExportSettings(
                videoCodec: .prores4444,
                width: 1920, height: 1080,
                frameRate: 30, videoBitRate: 330_000_000,
                audioCodec: .pcm, audioBitRate: 1_536_000,
                container: .mov
            )
        case .proresRaw:
            return ExportSettings(
                videoCodec: .proresRaw,
                width: 1920, height: 1080,
                frameRate: 30, videoBitRate: 500_000_000,
                audioCodec: .pcm, audioBitRate: 1_536_000,
                container: .mov
            )
        case .gif:
            return ExportSettings(
                videoCodec: .gif,
                width: 480, height: 270,
                frameRate: 15, videoBitRate: 0,
                audioCodec: .none, audioBitRate: 0,
                container: .gif
            )
        case .audioOnly:
            return ExportSettings(
                videoCodec: .none,
                width: 0, height: 0,
                frameRate: 0, videoBitRate: 0,
                audioCodec: .aac, audioBitRate: 320_000,
                container: .m4a
            )
        case .youtube:
            return ExportSettings(
                videoCodec: .h264,
                width: 1920, height: 1080,
                frameRate: 30, videoBitRate: 16_000_000,
                audioCodec: .aac, audioBitRate: 384_000,
                container: .mp4
            )
        case .tiktok:
            return ExportSettings(
                videoCodec: .h264,
                width: 1080, height: 1920,
                frameRate: 30, videoBitRate: 8_000_000,
                audioCodec: .aac, audioBitRate: 192_000,
                container: .mp4
            )
        case .instagram:
            return ExportSettings(
                videoCodec: .h264,
                width: 1080, height: 1080,
                frameRate: 30, videoBitRate: 8_000_000,
                audioCodec: .aac, audioBitRate: 192_000,
                container: .mp4
            )
        case .twitter:
            return ExportSettings(
                videoCodec: .h264,
                width: 1280, height: 720,
                frameRate: 30, videoBitRate: 5_000_000,
                audioCodec: .aac, audioBitRate: 128_000,
                container: .mp4
            )
        case .bilibili:
            return ExportSettings(
                videoCodec: .h264,
                width: 1920, height: 1080,
                frameRate: 60, videoBitRate: 15_000_000,
                audioCodec: .aac, audioBitRate: 320_000,
                container: .mp4
            )
        case .wechat:
            return ExportSettings(
                videoCodec: .h264,
                width: 1080, height: 1920,
                frameRate: 30, videoBitRate: 6_000_000,
                audioCodec: .aac, audioBitRate: 128_000,
                container: .mp4
            )
        case .custom:
            return ExportSettings()
        }
    }
}

/// 视频编解码器
enum VideoCodecType: String, CaseIterable, Codable {
    case h264 = "H.264"
    case hevc = "HEVC"
    case prores422 = "ProRes 422"
    case prores422hq = "ProRes 422 HQ"
    case prores4444 = "ProRes 4444"
    case proresRaw = "ProRes RAW"
    case vp9 = "VP9"
    case av1 = "AV1"
    case gif = "GIF"
    case none = "无"

    var avCodecKey: String? {
        switch self {
        case .h264: return AVVideoCodecType.h264.rawValue
        case .hevc: return AVVideoCodecType.hevc.rawValue
        case .prores422: return AVVideoCodecType.proRes422.rawValue
        case .prores422hq: return AVVideoCodecType.proRes422HQ.rawValue
        case .prores4444: return AVVideoCodecType.proRes4444.rawValue
        case .proresRaw: return "aprh" // ProRes RAW
        case .vp9: return "vp09"
        case .av1: return "av01"
        case .gif, .none: return nil
        }
    }
}

/// 音频编解码器
enum AudioCodecType: String, CaseIterable, Codable {
    case aac = "AAC"
    case mp3 = "MP3"
    case pcm = "PCM"
    case flac = "FLAC"
    case alac = "ALAC"
    case opus = "Opus"
    case none = "无"

    var formatID: AudioFormatID? {
        switch self {
        case .aac: return kAudioFormatMPEG4AAC
        case .mp3: return kAudioFormatMPEGLayer3
        case .pcm: return kAudioFormatLinearPCM
        case .flac: return kAudioFormatFLAC
        case .alac: return kAudioFormatAppleLossless
        case .opus: return kAudioFormatOpus
        case .none: return nil
        }
    }
}

/// 容器格式
enum ContainerFormat: String, CaseIterable, Codable {
    case mp4 = "MP4"
    case mov = "MOV"
    case mkv = "MKV"
    case webm = "WebM"
    case avi = "AVI"
    case gif = "GIF"
    case m4a = "M4A"
    case mp3 = "MP3"
    case wav = "WAV"

    var fileType: AVFileType {
        switch self {
        case .mp4: return .mp4
        case .mov: return .mov
        case .mkv: return .mp4 // MKV需要特殊处理
        case .webm: return .mp4
        case .avi: return .mp4  // AVI不被AVFoundation直接支持，使用MP4容器
        case .gif: return .mp4
        case .m4a: return .m4a
        case .mp3: return .mp3
        case .wav: return .wav
        }
    }

    var fileExtension: String {
        return rawValue.lowercased()
    }
}

/// 导出设置
struct ExportSettings: Codable {
    var videoCodec: VideoCodecType = .h264
    var width: Int = 1920
    var height: Int = 1080
    var frameRate: Double = 30
    var videoBitRate: Int = 10_000_000
    var keyFrameInterval: Int = 30
    var bFrames: Int = 2
    var profile: String = "high"
    var level: String = "4.1"

    var audioCodec: AudioCodecType = .aac
    var audioBitRate: Int = 192_000
    var audioSampleRate: Int = 48000
    var audioChannels: Int = 2

    var container: ContainerFormat = .mp4

    var quality: ExportQuality = .high
    var useHardwareEncoder: Bool = true
    var twoPass: Bool = false
    var optimizeForNetwork: Bool = true

    var timeRange: CMTimeRange?
    var cropRect: CGRect?
    var rotation: Int = 0

    var metadata: [String: String] = [:]

    enum ExportQuality: String, Codable, CaseIterable {
        case draft = "草稿"
        case low = "低"
        case medium = "中"
        case high = "高"
        case highest = "最高"
    }
}

// MARK: - 增强导出管理器

/// 增强导出管理器
class EnhancedExportManager: ObservableObject {
    static let shared = EnhancedExportManager()

    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0
    @Published var currentExportSettings: ExportSettings?
    @Published var estimatedFileSize: Int64 = 0
    @Published var estimatedTime: TimeInterval = 0

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var exportSession: AVAssetExportSession?
    private var compressionSession: VTCompressionSession?

    private let exportQueue = DispatchQueue(label: "com.videoeditor.export", qos: .userInitiated)

    // MARK: - 导出方法

    /// 导出视频
    func exportVideo(
        from composition: AVComposition,
        videoComposition: AVVideoComposition?,
        audioMix: AVAudioMix?,
        settings: ExportSettings,
        to outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        isExporting = true
        currentExportSettings = settings
        exportProgress = 0

        // 检查并删除已存在的文件
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        // 根据编码器选择导出方式
        if settings.videoCodec == .prores422 || settings.videoCodec == .prores422hq ||
           settings.videoCodec == .prores4444 || settings.videoCodec == .proresRaw {
            exportWithProRes(
                composition: composition,
                videoComposition: videoComposition,
                audioMix: audioMix,
                settings: settings,
                outputURL: outputURL,
                progress: progress,
                completion: completion
            )
        } else if settings.videoCodec == .gif {
            exportAsGIF(
                composition: composition,
                settings: settings,
                outputURL: outputURL,
                progress: progress,
                completion: completion
            )
        } else {
            exportWithStandard(
                composition: composition,
                videoComposition: videoComposition,
                audioMix: audioMix,
                settings: settings,
                outputURL: outputURL,
                progress: progress,
                completion: completion
            )
        }
    }

    /// 标准导出
    private func exportWithStandard(
        composition: AVComposition,
        videoComposition: AVVideoComposition?,
        audioMix: AVAudioMix?,
        settings: ExportSettings,
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let presetName = getExportPresetName(for: settings)

        guard let session = AVAssetExportSession(asset: composition, presetName: presetName) else {
            isExporting = false
            completion(.failure(NSError(domain: "ExportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"])))
            return
        }

        exportSession = session
        session.outputURL = outputURL
        session.outputFileType = settings.container.fileType
        session.shouldOptimizeForNetworkUse = settings.optimizeForNetwork

        if let videoComp = videoComposition {
            session.videoComposition = videoComp
        }

        if let mix = audioMix {
            session.audioMix = mix
        }

        if let timeRange = settings.timeRange {
            session.timeRange = timeRange
        }

        // 设置元数据
        session.metadata = createMetadataItems(from: settings.metadata)

        // 进度监控
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            let progressValue = Double(session.progress)
            self?.exportProgress = progressValue
            progress(progressValue)

            if session.status == .completed || session.status == .failed || session.status == .cancelled {
                timer.invalidate()
            }
        }

        session.exportAsynchronously { [weak self] in
            progressTimer.invalidate()

            DispatchQueue.main.async {
                self?.isExporting = false

                switch session.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed:
                    completion(.failure(session.error ?? NSError(domain: "ExportError", code: -2)))
                case .cancelled:
                    completion(.failure(NSError(domain: "ExportError", code: -3, userInfo: [NSLocalizedDescriptionKey: "导出已取消"])))
                default:
                    break
                }
            }
        }
    }

    /// ProRes导出
    private func exportWithProRes(
        composition: AVComposition,
        videoComposition: AVVideoComposition?,
        audioMix: AVAudioMix?,
        settings: ExportSettings,
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        exportQueue.async { [weak self] in
            do {
                // 创建AssetWriter
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
                self?.assetWriter = writer

                // 视频设置
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: settings.videoCodec.avCodecKey ?? AVVideoCodecType.proRes422.rawValue,
                    AVVideoWidthKey: settings.width,
                    AVVideoHeightKey: settings.height
                ]

                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = false
                self?.videoInput = videoInput

                // 音频设置
                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: settings.audioSampleRate,
                    AVNumberOfChannelsKey: settings.audioChannels,
                    AVLinearPCMBitDepthKey: 24,
                    AVLinearPCMIsFloatKey: false
                ]

                let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput.expectsMediaDataInRealTime = false
                self?.audioInput = audioInput

                writer.add(videoInput)
                writer.add(audioInput)

                // 创建Reader
                let reader = try AVAssetReader(asset: composition)

                let videoTrack = composition.tracks(withMediaType: .video).first
                let audioTrack = composition.tracks(withMediaType: .audio).first

                var videoOutput: AVAssetReaderOutput?
                if let track = videoTrack {
                    if let vc = videoComposition {
                        let output = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: nil)
                        output.videoComposition = vc
                        videoOutput = output
                    } else {
                        videoOutput = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
                    }
                    reader.add(videoOutput!)
                }

                var audioOutput: AVAssetReaderOutput?
                if let track = audioTrack {
                    if let mix = audioMix {
                        let output = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: nil)
                        output.audioMix = mix
                        audioOutput = output
                    } else {
                        audioOutput = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
                    }
                    reader.add(audioOutput!)
                }

                // 开始读写
                guard reader.startReading() && writer.startWriting() else {
                    throw reader.error ?? writer.error ?? NSError(domain: "ExportError", code: -4)
                }

                writer.startSession(atSourceTime: .zero)

                let totalDuration = composition.duration.seconds
                var processedTime: Double = 0

                // 处理视频
                let videoGroup = DispatchGroup()
                if let output = videoOutput {
                    videoGroup.enter()
                    videoInput.requestMediaDataWhenReady(on: self!.exportQueue) {
                        while videoInput.isReadyForMoreMediaData {
                            if let buffer = output.copyNextSampleBuffer() {
                                videoInput.append(buffer)

                                let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                                processedTime = pts.seconds

                                DispatchQueue.main.async {
                                    let prog = min(processedTime / totalDuration, 1.0)
                                    self?.exportProgress = prog
                                    progress(prog)
                                }
                            } else {
                                videoInput.markAsFinished()
                                videoGroup.leave()
                                break
                            }
                        }
                    }
                }

                // 处理音频
                let audioGroup = DispatchGroup()
                if let output = audioOutput {
                    audioGroup.enter()
                    audioInput.requestMediaDataWhenReady(on: self!.exportQueue) {
                        while audioInput.isReadyForMoreMediaData {
                            if let buffer = output.copyNextSampleBuffer() {
                                audioInput.append(buffer)
                            } else {
                                audioInput.markAsFinished()
                                audioGroup.leave()
                                break
                            }
                        }
                    }
                }

                // 等待完成
                videoGroup.wait()
                audioGroup.wait()

                let semaphore = DispatchSemaphore(value: 0)
                writer.finishWriting {
                    semaphore.signal()
                }
                semaphore.wait()

                DispatchQueue.main.async {
                    self?.isExporting = false
                    if writer.status == .completed {
                        completion(.success(outputURL))
                    } else {
                        completion(.failure(writer.error ?? NSError(domain: "ExportError", code: -5)))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isExporting = false
                    completion(.failure(error))
                }
            }
        }
    }

    /// GIF导出
    private func exportAsGIF(
        composition: AVComposition,
        settings: ExportSettings,
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        exportQueue.async { [weak self] in
            let generator = AVAssetImageGenerator(asset: composition)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: settings.width, height: settings.height)
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            let duration = composition.duration.seconds
            let frameCount = Int(duration * settings.frameRate)
            let frameDuration = 1.0 / settings.frameRate

            var images: [CGImage] = []

            for i in 0..<frameCount {
                let time = CMTime(seconds: Double(i) * frameDuration, preferredTimescale: 600)

                do {
                    let image = try generator.copyCGImage(at: time, actualTime: nil)
                    images.append(image)

                    DispatchQueue.main.async {
                        let prog = Double(i + 1) / Double(frameCount)
                        self?.exportProgress = prog * 0.8 // 80%用于提取帧
                        progress(prog * 0.8)
                    }
                } catch {
                    continue
                }
            }

            // 创建GIF
            guard let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                kUTTypeGIF,
                images.count,
                nil
            ) else {
                DispatchQueue.main.async {
                    self?.isExporting = false
                    completion(.failure(NSError(domain: "GIFError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建GIF"])))
                }
                return
            }

            let gifProperties: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFLoopCount: 0 // 无限循环
                ]
            ]
            CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

            let frameProperties: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: frameDuration
                ]
            ]

            for (index, image) in images.enumerated() {
                CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)

                DispatchQueue.main.async {
                    let prog = 0.8 + Double(index + 1) / Double(images.count) * 0.2
                    self?.exportProgress = prog
                    progress(prog)
                }
            }

            let success = CGImageDestinationFinalize(destination)

            DispatchQueue.main.async {
                self?.isExporting = false
                if success {
                    completion(.success(outputURL))
                } else {
                    completion(.failure(NSError(domain: "GIFError", code: -2, userInfo: [NSLocalizedDescriptionKey: "GIF创建失败"])))
                }
            }
        }
    }

    /// 取消导出
    func cancelExport() {
        exportSession?.cancelExport()
        assetWriter?.cancelWriting()
        isExporting = false
    }

    /// 估算文件大小
    func estimateFileSize(duration: TimeInterval, settings: ExportSettings) -> Int64 {
        let videoBits = Int64(settings.videoBitRate) * Int64(duration)
        let audioBits = Int64(settings.audioBitRate) * Int64(duration)
        let totalBits = videoBits + audioBits
        let bytes = totalBits / 8
        let overhead = Int64(Double(bytes) * 0.02) // 2%容器开销
        return bytes + overhead
    }

    /// 估算导出时间
    func estimateExportTime(duration: TimeInterval, settings: ExportSettings) -> TimeInterval {
        // 基于硬件能力和设置估算
        let baseMultiplier: Double

        switch settings.quality {
        case .draft: baseMultiplier = 0.5
        case .low: baseMultiplier = 0.8
        case .medium: baseMultiplier = 1.2
        case .high: baseMultiplier = 1.8
        case .highest: baseMultiplier = 3.0
        }

        let codecMultiplier: Double
        switch settings.videoCodec {
        case .h264: codecMultiplier = 1.0
        case .hevc: codecMultiplier = 1.5
        case .prores422, .prores422hq: codecMultiplier = 0.8
        case .prores4444, .proresRaw: codecMultiplier = 0.6
        default: codecMultiplier = 1.0
        }

        return duration * baseMultiplier * codecMultiplier
    }

    // MARK: - 辅助方法

    private func getExportPresetName(for settings: ExportSettings) -> String {
        if settings.videoCodec == .hevc {
            switch (settings.width, settings.height) {
            case (_, 2160): return AVAssetExportPresetHEVC3840x2160
            case (_, 1080): return AVAssetExportPresetHEVC1920x1080
            default: return AVAssetExportPresetHEVCHighestQuality
            }
        } else {
            switch (settings.width, settings.height) {
            case (_, 2160): return AVAssetExportPreset3840x2160
            case (_, 1080): return AVAssetExportPresetHighestQuality
            case (_, 720): return AVAssetExportPreset1280x720
            case (_, 480): return AVAssetExportPreset640x480
            default: return AVAssetExportPresetHighestQuality
            }
        }
    }

    private func createMetadataItems(from dictionary: [String: String]) -> [AVMetadataItem] {
        return dictionary.compactMap { key, value in
            let item = AVMutableMetadataItem()
            item.key = key as NSString
            item.keySpace = .common
            item.value = value as NSString
            return item
        }
    }
}

// MARK: - XML/EDL 导入导出

/// EDL时间码格式
enum EDLTimecodeFormat {
    case nonDropFrame
    case dropFrame
}

/// EDL条目
struct EDLEntry {
    var eventNumber: Int
    var reelName: String
    var trackType: TrackType
    var editType: EditType
    var sourceIn: String
    var sourceOut: String
    var recordIn: String
    var recordOut: String
    var comment: String?

    enum TrackType: String {
        case video = "V"
        case audio = "A"
        case audioVideo = "AA"
        case both = "B"
    }

    enum EditType: String {
        case cut = "C"
        case dissolve = "D"
        case wipe = "W"
        case keyEffect = "K"
    }
}

/// EDL解析器
class EDLParser {
    var title: String = ""
    var frameRate: Double = 30
    var timecodeFormat: EDLTimecodeFormat = .nonDropFrame
    var entries: [EDLEntry] = []

    /// 解析EDL文件
    func parse(url: URL) throws -> [EDLEntry] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parse(content: content)
    }

    /// 解析EDL内容
    func parse(content: String) -> [EDLEntry] {
        entries = []
        let lines = content.components(separatedBy: .newlines)

        var currentEntry: EDLEntry?

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // 解析标题
            if trimmedLine.hasPrefix("TITLE:") {
                title = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                continue
            }

            // 解析帧率
            if trimmedLine.hasPrefix("FCM:") {
                let fcm = String(trimmedLine.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                timecodeFormat = fcm == "DROP FRAME" ? .dropFrame : .nonDropFrame
                continue
            }

            // 解析事件行
            if let entry = parseEventLine(trimmedLine) {
                if let current = currentEntry {
                    entries.append(current)
                }
                currentEntry = entry
                continue
            }

            // 解析注释
            if trimmedLine.hasPrefix("*") {
                if var entry = currentEntry {
                    let comment = String(trimmedLine.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                    entry.comment = (entry.comment ?? "") + comment + "\n"
                    currentEntry = entry
                }
            }
        }

        if let lastEntry = currentEntry {
            entries.append(lastEntry)
        }

        return entries
    }

    private func parseEventLine(_ line: String) -> EDLEntry? {
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard components.count >= 8,
              let eventNumber = Int(components[0]) else {
            return nil
        }

        let reelName = components[1]
        let trackTypeStr = components[2]
        let editTypeStr = components[3]

        let trackType: EDLEntry.TrackType
        switch trackTypeStr {
        case "V": trackType = .video
        case "A": trackType = .audio
        case "AA": trackType = .audioVideo
        case "B": trackType = .both
        default: trackType = .video
        }

        let editType: EDLEntry.EditType
        switch editTypeStr {
        case "C": editType = .cut
        case "D": editType = .dissolve
        case "W": editType = .wipe
        case "K": editType = .keyEffect
        default: editType = .cut
        }

        return EDLEntry(
            eventNumber: eventNumber,
            reelName: reelName,
            trackType: trackType,
            editType: editType,
            sourceIn: components[4],
            sourceOut: components[5],
            recordIn: components[6],
            recordOut: components[7]
        )
    }

    /// 生成EDL内容
    func generate(title: String, entries: [EDLEntry], frameRate: Double = 30) -> String {
        var output = "TITLE: \(title)\n"
        output += "FCM: \(timecodeFormat == .dropFrame ? "DROP FRAME" : "NON-DROP FRAME")\n\n"

        for entry in entries {
            let line = String(format: "%03d  %s %s %s    %s %s %s %s",
                            entry.eventNumber,
                            entry.reelName,
                            entry.trackType.rawValue,
                            entry.editType.rawValue,
                            entry.sourceIn,
                            entry.sourceOut,
                            entry.recordIn,
                            entry.recordOut)
            output += line + "\n"

            if let comment = entry.comment {
                output += "* \(comment)\n"
            }
        }

        return output
    }
}

/// FCP XML解析器
class FCPXMLParser: NSObject, XMLParserDelegate {
    private var currentElement: String = ""
    private var currentAttributes: [String: String] = [:]
    private var clips: [FCPXMLClip] = []
    private var currentClip: FCPXMLClip?

    struct FCPXMLClip {
        var name: String = ""
        var duration: CMTime = .zero
        var start: CMTime = .zero
        var offset: CMTime = .zero
        var src: String = ""
        var formatRef: String = ""
        var audioRole: String = ""
        var videoRole: String = ""
    }

    /// 解析FCP XML
    func parse(url: URL) throws -> [FCPXMLClip] {
        let parser = XMLParser(contentsOf: url)
        parser?.delegate = self
        parser?.parse()
        return clips
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict

        switch elementName {
        case "clip", "asset-clip", "ref-clip":
            currentClip = FCPXMLClip()
            currentClip?.name = attributeDict["name"] ?? ""
            currentClip?.src = attributeDict["src"] ?? ""
            currentClip?.formatRef = attributeDict["format"] ?? ""

            if let durationStr = attributeDict["duration"] {
                currentClip?.duration = parseTime(durationStr)
            }
            if let startStr = attributeDict["start"] {
                currentClip?.start = parseTime(startStr)
            }
            if let offsetStr = attributeDict["offset"] {
                currentClip?.offset = parseTime(offsetStr)
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if (elementName == "clip" || elementName == "asset-clip" || elementName == "ref-clip"),
           let clip = currentClip {
            clips.append(clip)
            currentClip = nil
        }
    }

    private func parseTime(_ timeString: String) -> CMTime {
        // 解析FCP时间格式 "1001/30000s"
        let components = timeString.replacingOccurrences(of: "s", with: "").components(separatedBy: "/")
        if components.count == 2,
           let value = Int64(components[0]),
           let timescale = Int32(components[1]) {
            return CMTime(value: value, timescale: timescale)
        }
        return .zero
    }

    /// 生成FCP XML
    func generateXML(projectName: String, clips: [FCPXMLClip], frameRate: Double = 30) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="1.10">
            <resources>
                <format id="r1" name="FFVideoFormat1080p\(Int(frameRate))" frameDuration="1/\(Int(frameRate))s" width="1920" height="1080"/>
            </resources>
            <library>
                <event name="\(projectName)">
                    <project name="\(projectName)">
                        <sequence format="r1">
                            <spine>
        """

        for clip in clips {
            let durationStr = "\(clip.duration.value)/\(clip.duration.timescale)s"
            let offsetStr = "\(clip.offset.value)/\(clip.offset.timescale)s"

            xml += """
                                <asset-clip name="\(clip.name)" offset="\(offsetStr)" duration="\(durationStr)" src="\(clip.src)"/>
            """
        }

        xml += """
                            </spine>
                        </sequence>
                    </project>
                </event>
            </library>
        </fcpxml>
        """

        return xml
    }
}

// MARK: - 社交媒体发布

/// 发布平台
enum PublishPlatform: String, CaseIterable {
    case youtube = "YouTube"
    case tiktok = "TikTok"
    case instagram = "Instagram"
    case twitter = "Twitter"
    case facebook = "Facebook"
    case bilibili = "哔哩哔哩"
    case weibo = "微博"
    case wechat = "微信视频号"
    case douyin = "抖音"
    case kuaishou = "快手"
    case xiaohongshu = "小红书"

    var maxDuration: TimeInterval {
        switch self {
        case .youtube: return 43200 // 12小时
        case .tiktok, .douyin: return 600 // 10分钟
        case .instagram: return 3600 // 60分钟(IGTV)
        case .twitter: return 140 // 2分20秒
        case .facebook: return 14400 // 4小时
        case .bilibili: return 7200 // 2小时
        case .weibo: return 3600 // 60分钟
        case .wechat: return 1800 // 30分钟
        case .kuaishou: return 600 // 10分钟
        case .xiaohongshu: return 600 // 10分钟
        }
    }

    var maxFileSize: Int64 {
        switch self {
        case .youtube: return 256 * 1024 * 1024 * 1024 // 256GB
        case .tiktok, .douyin: return 4 * 1024 * 1024 * 1024 // 4GB
        case .instagram: return 4 * 1024 * 1024 * 1024 // 4GB
        case .twitter: return 512 * 1024 * 1024 // 512MB
        case .facebook: return 10 * 1024 * 1024 * 1024 // 10GB
        case .bilibili: return 8 * 1024 * 1024 * 1024 // 8GB
        case .weibo: return 5 * 1024 * 1024 * 1024 // 5GB
        case .wechat: return 1024 * 1024 * 1024 // 1GB
        case .kuaishou: return 4 * 1024 * 1024 * 1024 // 4GB
        case .xiaohongshu: return 4 * 1024 * 1024 * 1024 // 4GB
        }
    }

    var recommendedAspectRatio: CGFloat {
        switch self {
        case .youtube: return 16.0 / 9.0
        case .tiktok, .douyin, .instagram, .wechat, .kuaishou, .xiaohongshu: return 9.0 / 16.0
        case .twitter, .facebook, .bilibili, .weibo: return 16.0 / 9.0
        }
    }

    var exportSettings: ExportSettings {
        switch self {
        case .youtube: return ExportPresetType.youtube.settings
        case .tiktok, .douyin: return ExportPresetType.tiktok.settings
        case .instagram: return ExportPresetType.instagram.settings
        case .twitter: return ExportPresetType.twitter.settings
        case .bilibili: return ExportPresetType.bilibili.settings
        case .wechat: return ExportPresetType.wechat.settings
        default: return ExportPresetType.h264_1080p.settings
        }
    }
}

/// 发布选项
struct PublishOptions {
    var title: String = ""
    var description: String = ""
    var tags: [String] = []
    var category: String = ""
    var privacy: Privacy = .public
    var thumbnail: URL?
    var scheduledDate: Date?
    var playlist: String?
    var allowComments: Bool = true
    var allowDuet: Bool = true
    var allowStitch: Bool = true

    enum Privacy: String, CaseIterable {
        case `public` = "公开"
        case `private` = "私密"
        case unlisted = "不公开"
        case friends = "仅好友"
    }
}

/// 发布管理器
class PublishManager: ObservableObject {
    static let shared = PublishManager()

    @Published var isPublishing: Bool = false
    @Published var uploadProgress: Double = 0
    @Published var publishedURLs: [String: URL] = [:]

    /// 发布到平台
    func publish(
        videoURL: URL,
        to platform: PublishPlatform,
        options: PublishOptions,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        isPublishing = true
        uploadProgress = 0

        // 验证视频
        let asset = AVAsset(url: videoURL)
        let duration = asset.duration.seconds

        if duration > platform.maxDuration {
            isPublishing = false
            completion(.failure(NSError(domain: "PublishError", code: -1, userInfo: [NSLocalizedDescriptionKey: "视频时长超过\(platform.rawValue)限制"])))
            return
        }

        // 检查文件大小
        if let attrs = try? FileManager.default.attributesOfItem(atPath: videoURL.path),
           let size = attrs[.size] as? Int64,
           size > platform.maxFileSize {
            isPublishing = false
            completion(.failure(NSError(domain: "PublishError", code: -2, userInfo: [NSLocalizedDescriptionKey: "文件大小超过\(platform.rawValue)限制"])))
            return
        }

        // 模拟上传过程
        simulateUpload(platform: platform, options: options, progress: progress, completion: completion)
    }

    private func simulateUpload(
        platform: PublishPlatform,
        options: PublishOptions,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 这里应该实现实际的API调用
        // 目前使用模拟
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.uploadProgress += 0.02
            progress(self.uploadProgress)

            if self.uploadProgress >= 1.0 {
                timer.invalidate()
                self.isPublishing = false

                // 生成模拟的发布URL
                let publishedURL = URL(string: "https://\(platform.rawValue.lowercased()).com/video/\(UUID().uuidString)")!
                self.publishedURLs[platform.rawValue] = publishedURL

                completion(.success(publishedURL))
            }
        }

        RunLoop.main.add(timer, forMode: .common)
    }

    /// 获取平台授权
    func authorize(platform: PublishPlatform, completion: @escaping (Bool) -> Void) {
        // 实现OAuth授权流程
        // 这里是占位实现
        completion(true)
    }

    /// 检查授权状态
    func isAuthorized(platform: PublishPlatform) -> Bool {
        // 检查保存的授权token
        return false
    }

    /// 取消发布
    func cancelPublish() {
        isPublishing = false
        uploadProgress = 0
    }
}

// MARK: - 批量导出

/// 批量导出任务
struct BatchExportTask: Identifiable {
    let id: UUID
    var inputURL: URL
    var outputURL: URL
    var settings: ExportSettings
    var progress: Double = 0
    var status: TaskStatus = .pending
    var error: Error?

    enum TaskStatus {
        case pending
        case processing
        case completed
        case failed
        case cancelled
    }
}

/// 批量导出管理器
class BatchExportManager: ObservableObject {
    static let shared = BatchExportManager()

    @Published var tasks: [BatchExportTask] = []
    @Published var isProcessing: Bool = false
    @Published var overallProgress: Double = 0

    private var currentTaskIndex: Int = 0

    /// 添加批量导出任务
    func addTasks(_ newTasks: [BatchExportTask]) {
        tasks.append(contentsOf: newTasks)
    }

    /// 开始批量导出
    func startBatchExport(completion: @escaping (Int, Int) -> Void) {
        guard !isProcessing else { return }

        isProcessing = true
        currentTaskIndex = 0
        processNextTask(completion: completion)
    }

    private func processNextTask(completion: @escaping (Int, Int) -> Void) {
        guard currentTaskIndex < tasks.count else {
            isProcessing = false
            let completed = tasks.filter { $0.status == .completed }.count
            let failed = tasks.filter { $0.status == .failed }.count
            completion(completed, failed)
            return
        }

        tasks[currentTaskIndex].status = .processing

        // 模拟导出
        let taskIndex = currentTaskIndex

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.tasks[taskIndex].progress += 0.05

            if self.tasks[taskIndex].progress >= 1.0 {
                timer.invalidate()
                self.tasks[taskIndex].status = .completed
                self.currentTaskIndex += 1
                self.updateOverallProgress()
                self.processNextTask(completion: completion)
            }
        }
    }

    private func updateOverallProgress() {
        let totalProgress = tasks.reduce(0.0) { $0 + $1.progress }
        overallProgress = totalProgress / Double(tasks.count)
    }

    /// 取消批量导出
    func cancelBatchExport() {
        isProcessing = false
        for i in currentTaskIndex..<tasks.count {
            tasks[i].status = .cancelled
        }
    }

    /// 重试失败任务
    func retryFailedTasks(completion: @escaping (Int, Int) -> Void) {
        for i in 0..<tasks.count {
            if tasks[i].status == .failed {
                tasks[i].status = .pending
                tasks[i].progress = 0
                tasks[i].error = nil
            }
        }

        currentTaskIndex = tasks.firstIndex { $0.status == .pending } ?? tasks.count
        startBatchExport(completion: completion)
    }
}

// MARK: - 导入管理器

/// 支持的导入格式
enum ImportFormat: String, CaseIterable {
    // 视频
    case mp4, mov, m4v, avi, mkv, wmv, flv, webm, `3gp`, mts, m2ts

    // 音频
    case mp3, wav, aac, m4a, flac, ogg, wma, aiff

    // 图片
    case jpg, jpeg, png, heic, heif, tiff, bmp, gif, webp, raw, dng

    // 项目文件
    case fcpxml, edl, aaf, xml

    var category: ImportCategory {
        switch self {
        case .mp4, .mov, .m4v, .avi, .mkv, .wmv, .flv, .webm, .`3gp`, .mts, .m2ts:
            return .video
        case .mp3, .wav, .aac, .m4a, .flac, .ogg, .wma, .aiff:
            return .audio
        case .jpg, .jpeg, .png, .heic, .heif, .tiff, .bmp, .gif, .webp, .raw, .dng:
            return .image
        case .fcpxml, .edl, .aaf, .xml:
            return .project
        }
    }

    enum ImportCategory {
        case video
        case audio
        case image
        case project
    }
}

/// 导入选项
struct ImportOptions {
    var createProxy: Bool = false
    var proxyResolution: ProxyResolution = .half
    var analyzeAudio: Bool = true
    var generateThumbnails: Bool = true
    var copyToLibrary: Bool = false
    var organizeByDate: Bool = false

    enum ProxyResolution: String, CaseIterable {
        case quarter = "1/4"
        case half = "1/2"
        case original = "原始"
    }
}

/// 增强导入管理器
class EnhancedImportManager: ObservableObject {
    static let shared = EnhancedImportManager()

    @Published var isImporting: Bool = false
    @Published var importProgress: Double = 0
    @Published var importedItems: [ImportedItem] = []

    struct ImportedItem: Identifiable {
        let id: UUID
        var url: URL
        var format: ImportFormat
        var duration: TimeInterval?
        var resolution: CGSize?
        var thumbnailURL: URL?
        var proxyURL: URL?
        var waveformData: [Float]?
    }

    /// 导入文件
    func importFiles(
        urls: [URL],
        options: ImportOptions,
        progress: @escaping (Double, String) -> Void,
        completion: @escaping ([ImportedItem]) -> Void
    ) {
        isImporting = true
        importProgress = 0
        importedItems = []

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var items: [ImportedItem] = []

            for (index, url) in urls.enumerated() {
                let ext = url.pathExtension.lowercased()
                guard let format = ImportFormat(rawValue: ext) else { continue }

                var item = ImportedItem(id: UUID(), url: url, format: format)

                // 获取元数据
                switch format.category {
                case .video:
                    let asset = AVAsset(url: url)
                    item.duration = asset.duration.seconds
                    if let track = asset.tracks(withMediaType: .video).first {
                        item.resolution = track.naturalSize
                    }

                    // 生成缩略图
                    if options.generateThumbnails {
                        item.thumbnailURL = self?.generateThumbnail(for: url)
                    }

                    // 创建代理
                    if options.createProxy {
                        item.proxyURL = self?.createProxy(for: url, resolution: options.proxyResolution)
                    }

                case .audio:
                    let asset = AVAsset(url: url)
                    item.duration = asset.duration.seconds

                    // 分析音频波形
                    if options.analyzeAudio {
                        item.waveformData = self?.analyzeWaveform(url: url)
                    }

                case .image:
                    // 获取图片尺寸
                    if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                       let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                        let width = props[kCGImagePropertyPixelWidth as String] as? Int ?? 0
                        let height = props[kCGImagePropertyPixelHeight as String] as? Int ?? 0
                        item.resolution = CGSize(width: width, height: height)
                    }

                case .project:
                    // 解析项目文件
                    break
                }

                items.append(item)

                DispatchQueue.main.async {
                    let prog = Double(index + 1) / Double(urls.count)
                    self?.importProgress = prog
                    progress(prog, url.lastPathComponent)
                }
            }

            DispatchQueue.main.async {
                self?.isImporting = false
                self?.importedItems = items
                completion(items)
            }
        }
    }

    private func generateThumbnail(for url: URL) -> URL? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)

        guard let image = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }

        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let thumbnailURL = tempDir.appendingPathComponent("\(UUID().uuidString).jpg")

        #if canImport(AppKit)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        if let tiffData = nsImage.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiffData),
           let jpegData = rep.representation(using: .jpeg, properties: [:]) {
            try? jpegData.write(to: thumbnailURL)
            return thumbnailURL
        }
        #elseif canImport(UIKit)
        let uiImage = UIImage(cgImage: image)
        if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
            try? jpegData.write(to: thumbnailURL)
            return thumbnailURL
        }
        #endif

        return nil
    }

    private func createProxy(for url: URL, resolution: ImportOptions.ProxyResolution) -> URL? {
        let asset = AVAsset(url: url)

        let presetName: String
        switch resolution {
        case .quarter: presetName = AVAssetExportPreset640x480
        case .half: presetName = AVAssetExportPreset1280x720
        case .original: presetName = AVAssetExportPresetHighestQuality
        }

        guard let session = AVAssetExportSession(asset: asset, presetName: presetName) else { return nil }

        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let proxyURL = tempDir.appendingPathComponent("\(UUID().uuidString)_proxy.mp4")

        session.outputURL = proxyURL
        session.outputFileType = .mp4

        let semaphore = DispatchSemaphore(value: 0)
        session.exportAsynchronously {
            semaphore.signal()
        }
        semaphore.wait()

        return session.status == .completed ? proxyURL : nil
    }

    private func analyzeWaveform(url: URL) -> [Float]? {
        let asset = AVAsset(url: url)
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else { return nil }

        guard let reader = try? AVAssetReader(asset: asset) else { return nil }

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
            guard let blockBuffer = CMSampleBufferGetDataBuffer(buffer) else { continue }

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

        return samples
    }
}
