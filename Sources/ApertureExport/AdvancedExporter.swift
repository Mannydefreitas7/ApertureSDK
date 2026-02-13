import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - 高级导出器

/// 高级导出器
class AdvancedExporter: ObservableObject {

    @Published var isExporting = false
    @Published var progress: Float = 0
    @Published var currentStep: String = ""

    // MARK: - GIF 导出

    /// GIF 导出配置
    struct GIFConfiguration {
        var fps: Int = 15
        var width: Int = 480
        var loopCount: Int = 0  // 0 = 无限循环
        var quality: Float = 0.8
        var timeRange: CMTimeRange?

        /// 预设
        enum Preset: String, CaseIterable {
            case small = "小尺寸"
            case medium = "中等"
            case large = "大尺寸"
            case highQuality = "高质量"

            var config: GIFConfiguration {
                switch self {
                case .small: return GIFConfiguration(fps: 10, width: 320, quality: 0.6)
                case .medium: return GIFConfiguration(fps: 15, width: 480, quality: 0.7)
                case .large: return GIFConfiguration(fps: 15, width: 640, quality: 0.8)
                case .highQuality: return GIFConfiguration(fps: 20, width: 720, quality: 0.9)
                }
            }
        }
    }

    /// 导出为 GIF
    func exportGIF(
        from asset: AVAsset,
        to outputURL: URL,
        configuration: GIFConfiguration
    ) async throws {
        await MainActor.run {
            isExporting = true
            progress = 0
            currentStep = "正在生成 GIF..."
        }

        let duration = try await asset.load(.duration)
        let timeRange = configuration.timeRange ?? CMTimeRange(start: .zero, duration: duration)
        let durationSeconds = CMTimeGetSeconds(timeRange.duration)
        let totalFrames = Int(durationSeconds * Double(configuration.fps))

        // 生成帧
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        // 计算缩放后的尺寸
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let naturalSize = try await videoTracks.first?.load(.naturalSize) ?? CGSize(width: 1920, height: 1080)
        let aspectRatio = naturalSize.width / naturalSize.height
        let targetSize = CGSize(
            width: configuration.width,
            height: Int(CGFloat(configuration.width) / aspectRatio)
        )
        generator.maximumSize = targetSize

        var frames: [CGImage] = []

        for i in 0..<totalFrames {
            let time = CMTimeAdd(
                timeRange.start,
                CMTime(seconds: Double(i) / Double(configuration.fps), preferredTimescale: 600)
            )

            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                frames.append(cgImage)
            } catch {
                continue
            }

            await MainActor.run {
                progress = Float(i) / Float(totalFrames) * 0.8
            }
        }

        await MainActor.run {
            currentStep = "正在编码 GIF..."
        }

        // 创建 GIF
        let fileProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: configuration.loopCount
            ]
        ]

        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: 1.0 / Double(configuration.fps)
            ]
        ]

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw AdvancedExportError.failedToCreateDestination
        }

        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        for (index, frame) in frames.enumerated() {
            CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)

            await MainActor.run {
                progress = 0.8 + Float(index) / Float(frames.count) * 0.2
            }
        }

        guard CGImageDestinationFinalize(destination) else {
            throw AdvancedExportError.failedToFinalize
        }

        await MainActor.run {
            isExporting = false
            progress = 1.0
            currentStep = "完成"
        }
    }

    // MARK: - 序列帧导出

    /// 序列帧导出配置
    struct SequenceConfiguration {
        var format: ImageFormat = .png
        var fps: Int = 30
        var width: Int?  // nil 表示原始尺寸
        var quality: Float = 1.0
        var timeRange: CMTimeRange?
        var namePrefix: String = "frame"

        enum ImageFormat: String, CaseIterable {
            case png = "PNG"
            case jpeg = "JPEG"
            case tiff = "TIFF"

            var fileExtension: String {
                switch self {
                case .png: return "png"
                case .jpeg: return "jpg"
                case .tiff: return "tiff"
                }
            }

            var utType: UTType {
                switch self {
                case .png: return .png
                case .jpeg: return .jpeg
                case .tiff: return .tiff
                }
            }
        }
    }

    /// 导出为序列帧
    func exportImageSequence(
        from asset: AVAsset,
        to outputDirectory: URL,
        configuration: SequenceConfiguration
    ) async throws -> [URL] {
        await MainActor.run {
            isExporting = true
            progress = 0
            currentStep = "正在导出序列帧..."
        }

        // 创建输出目录
        if !FileManager.default.fileExists(atPath: outputDirectory.path) {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }

        let duration = try await asset.load(.duration)
        let timeRange = configuration.timeRange ?? CMTimeRange(start: .zero, duration: duration)
        let durationSeconds = CMTimeGetSeconds(timeRange.duration)
        let totalFrames = Int(durationSeconds * Double(configuration.fps))

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        if let width = configuration.width {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let naturalSize = try await videoTracks.first?.load(.naturalSize) ?? CGSize(width: 1920, height: 1080)
            let aspectRatio = naturalSize.width / naturalSize.height
            generator.maximumSize = CGSize(width: width, height: Int(CGFloat(width) / aspectRatio))
        }

        var outputURLs: [URL] = []
        let digitCount = String(totalFrames).count

        for i in 0..<totalFrames {
            let time = CMTimeAdd(
                timeRange.start,
                CMTime(seconds: Double(i) / Double(configuration.fps), preferredTimescale: 600)
            )

            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)

                let frameNumber = String(format: "%0\(digitCount)d", i)
                let fileName = "\(configuration.namePrefix)_\(frameNumber).\(configuration.format.fileExtension)"
                let fileURL = outputDirectory.appendingPathComponent(fileName)

                try saveImage(cgImage, to: fileURL, format: configuration.format, quality: configuration.quality)
                outputURLs.append(fileURL)
            } catch {
                print("跳过帧 \(i): \(error)")
            }

            await MainActor.run {
                progress = Float(i) / Float(totalFrames)
            }
        }

        await MainActor.run {
            isExporting = false
            progress = 1.0
            currentStep = "完成"
        }

        return outputURLs
    }

    /// 保存图像
    private func saveImage(_ image: CGImage, to url: URL, format: SequenceConfiguration.ImageFormat, quality: Float) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw AdvancedExportError.failedToCreateDestination
        }

        var properties: [String: Any] = [:]

        if format == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality as String] = quality
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw AdvancedExportError.failedToFinalize
        }
    }

    // MARK: - 音频单独导出

    /// 音频导出配置
    struct AudioExportConfiguration {
        var format: AudioFormat = .m4a
        var quality: AudioQuality = .high
        var timeRange: CMTimeRange?

        enum AudioFormat: String, CaseIterable {
            case m4a = "M4A (AAC)"
            case mp3 = "MP3"
            case wav = "WAV"
            case aiff = "AIFF"

            var fileExtension: String {
                switch self {
                case .m4a: return "m4a"
                case .mp3: return "mp3"
                case .wav: return "wav"
                case .aiff: return "aiff"
                }
            }

            var fileType: AVFileType {
                switch self {
                case .m4a: return .m4a
                case .mp3: return .mp3
                case .wav: return .wav
                case .aiff: return .aiff
                }
            }

            var preset: String {
                switch self {
                case .m4a: return AVAssetExportPresetAppleM4A
                case .mp3: return AVAssetExportPresetPassthrough
                case .wav: return AVAssetExportPresetPassthrough
                case .aiff: return AVAssetExportPresetPassthrough
                }
            }
        }

        enum AudioQuality: String, CaseIterable {
            case low = "低 (96kbps)"
            case medium = "中 (128kbps)"
            case high = "高 (256kbps)"
            case lossless = "无损"

            var bitRate: Int {
                switch self {
                case .low: return 96000
                case .medium: return 128000
                case .high: return 256000
                case .lossless: return 0
                }
            }
        }
    }

    /// 导出音频
    func exportAudio(
        from asset: AVAsset,
        to outputURL: URL,
        configuration: AudioExportConfiguration
    ) async throws {
        await MainActor.run {
            isExporting = true
            progress = 0
            currentStep = "正在导出音频..."
        }

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: configuration.format.preset
        ) else {
            throw ExportError.failedToCreateSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = configuration.format.fileType

        if let timeRange = configuration.timeRange {
            exportSession.timeRange = timeRange
        }

        // 删除已存在的文件
        try? FileManager.default.removeItem(at: outputURL)

        // 监控进度
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.progress = exportSession.progress
            }
        }

        await exportSession.export()
        progressTimer.invalidate()

        if exportSession.status != .completed {
            throw exportSession.error ?? ExportError.unknown
        }

        await MainActor.run {
            isExporting = false
            progress = 1.0
            currentStep = "完成"
        }
    }

    // MARK: - 社交媒体预设

    /// 社交媒体平台
    enum SocialMediaPlatform: String, CaseIterable {
        case tiktok = "抖音/TikTok"
        case instagram_reels = "Instagram Reels"
        case instagram_story = "Instagram Story"
        case instagram_feed = "Instagram Feed"
        case youtube = "YouTube"
        case youtube_shorts = "YouTube Shorts"
        case bilibili = "B站"
        case weibo = "微博"
        case wechat = "微信视频号"
        case twitter = "Twitter/X"
        case facebook = "Facebook"

        var icon: String {
            switch self {
            case .tiktok: return "music.note"
            case .instagram_reels, .instagram_story, .instagram_feed: return "camera"
            case .youtube, .youtube_shorts: return "play.rectangle"
            case .bilibili: return "tv"
            case .weibo: return "text.bubble"
            case .wechat: return "message"
            case .twitter: return "at"
            case .facebook: return "person.2"
            }
        }

        /// 导出配置
        var exportConfig: SocialMediaExportConfig {
            switch self {
            case .tiktok:
                return SocialMediaExportConfig(
                    resolution: CGSize(width: 1080, height: 1920),
                    aspectRatio: "9:16",
                    maxDuration: 180,
                    maxFileSize: 287 * 1024 * 1024,  // 287MB
                    recommendedBitrate: 8_000_000,
                    frameRate: 30
                )
            case .instagram_reels:
                return SocialMediaExportConfig(
                    resolution: CGSize(width: 1080, height: 1920),
                    aspectRatio: "9:16",
                    maxDuration: 90,
                    maxFileSize: 250 * 1024 * 1024,
                    recommendedBitrate: 6_000_000,
                    frameRate: 30
                )
            case .instagram_story:
                return SocialMediaExportConfig(
                    resolution: CGSize(width: 1080, height: 1920),
                    aspectRatio: "9:16",
                    maxDuration: 60,
                    maxFileSize: 250 * 1024 * 1024,
                    recommendedBitrate: 6_000_000,
                    frameRate: 30
                )
            case .instagram_feed:
                return SocialMediaExportConfig(
                    resolution: CGSize(width: 1080, height: 1080),
                    aspectRatio: "1:1",
                    maxDuration: 60,
                    maxFileSize: 250 * 1024 * 1024,
                    recommendedBitrate: 5_000_000,
                    frameRate: 30
                )
            case .youtube:
                return SocialMediaExportConfig(
                    resolution: CGSize(width: 1920, height: 1080),
                    aspectRatio: "16:9",
                    maxDuration: nil,
                    maxFileSize: 256 * 1024 * 1024 * 1024,  // 256GB
                    recommendedBitrate: 16_000_000,
                    frameRate: 30
                )
            case .youtube_shorts:
                return SocialMediaExportConfig(
                    resolution: CGSize(width: 1080, height: 1920),
                    aspectRatio: "9:16",
                    maxDuration: 60,
                    maxFileSize: 256 * 1024 * 1024 * 1024,
                    recommendedBitrate: 8_000_000,
                    frameRate: 30
                )
            case .bilibili:
                return SocialMediaExportConfig(
                    resolution: CGSize(width: 1920, height: 1080),
                    aspectRatio: "16:9",
                    maxDuration: nil,
                    maxFileSize: 8 * 1024 * 1024 * 1024,  // 8GB
                    recommendedBitrate: 10_000_000,
                    frameRate: 30
                )
            case .weibo:
                return SocialMediaExportConfig(
                    resolution: CGSize(width: 1280, height: 720),
                    aspectRatio: "16:9",
                    maxDuration: 900,
                    maxFileSize: 500 * 1024 * 1024,
                    recommendedBitrate: 4_000_000,
                    frameRate: 30
                )
            case .wechat:
                return SocialMediaExportConfig(
                    resolution: CGSize(width: 1080, height: 1920),
                    aspectRatio: "9:16",
                    maxDuration: 30,
                    maxFileSize: 30 * 1024 * 1024,
                    recommendedBitrate: 4_000_000,
                    frameRate: 30
                )
            case .twitter:
                return SocialMediaExportConfig(
                    resolution: CGSize(width: 1280, height: 720),
                    aspectRatio: "16:9",
                    maxDuration: 140,
                    maxFileSize: 512 * 1024 * 1024,
                    recommendedBitrate: 5_000_000,
                    frameRate: 30
                )
            case .facebook:
                return SocialMediaExportConfig(
                    resolution: CGSize(width: 1280, height: 720),
                    aspectRatio: "16:9",
                    maxDuration: 240 * 60,  // 4小时
                    maxFileSize: 4 * 1024 * 1024 * 1024,
                    recommendedBitrate: 6_000_000,
                    frameRate: 30
                )
            }
        }
    }

    /// 社交媒体导出配置
    struct SocialMediaExportConfig {
        var resolution: CGSize
        var aspectRatio: String
        var maxDuration: TimeInterval?  // 秒，nil 表示无限制
        var maxFileSize: Int64  // 字节
        var recommendedBitrate: Int
        var frameRate: Double
    }

    /// 为社交媒体导出
    func exportForSocialMedia(
        project: Project,
        platform: SocialMediaPlatform,
        outputURL: URL
    ) async throws {
        await MainActor.run {
            isExporting = true
            progress = 0
            currentStep = "正在为 \(platform.rawValue) 优化导出..."
        }

        let config = platform.exportConfig

        // 检查时长限制
        let duration = CMTimeGetSeconds(project.duration)
        if let maxDuration = config.maxDuration, duration > maxDuration {
            await MainActor.run {
                currentStep = "警告：视频时长超过平台限制"
            }
        }

        // 构建合成
        let result = try await CompositionBuilder.buildComposition(from: project)

        // 配置导出
        guard let exportSession = AVAssetExportSession(
            asset: result.composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.failedToCreateSession
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = result.videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        // 删除已存在的文件
        try? FileManager.default.removeItem(at: outputURL)

        // 监控进度
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.progress = exportSession.progress
            }
        }

        await exportSession.export()
        progressTimer.invalidate()

        if exportSession.status != .completed {
            throw exportSession.error ?? ExportError.unknown
        }

        // 检查文件大小
        let fileSize = try FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64 ?? 0
        if fileSize > config.maxFileSize {
            await MainActor.run {
                currentStep = "警告：文件大小超过平台限制"
            }
        }

        await MainActor.run {
            isExporting = false
            progress = 1.0
            currentStep = "完成"
        }
    }

    // MARK: - 批量导出

    /// 批量导出配置
    struct BatchExportConfiguration {
        var formats: [VideoExporter.ExportPreset]
        var platforms: [SocialMediaPlatform]
        var includeGIF: Bool = false
        var gifConfig: GIFConfiguration?
    }

    /// 批量导出
    func batchExport(
        project: Project,
        to outputDirectory: URL,
        configuration: BatchExportConfiguration
    ) async throws -> [URL] {
        await MainActor.run {
            isExporting = true
            progress = 0
            currentStep = "正在批量导出..."
        }

        var outputURLs: [URL] = []
        let totalTasks = configuration.formats.count + configuration.platforms.count + (configuration.includeGIF ? 1 : 0)
        var completedTasks = 0

        // 创建输出目录
        if !FileManager.default.fileExists(atPath: outputDirectory.path) {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }

        // 导出不同格式
        let exporter = VideoExporter()
        for preset in configuration.formats {
            let fileName = "\(project.name)_\(preset.displayName).mp4"
            let outputURL = outputDirectory.appendingPathComponent(fileName)

            await MainActor.run {
                currentStep = "正在导出 \(preset.displayName)..."
            }

            let config = VideoExporter.ExportConfiguration(preset: preset)
            try await exporter.export(project: project, to: outputURL, configuration: config)

            outputURLs.append(outputURL)
            completedTasks += 1

            await MainActor.run {
                progress = Float(completedTasks) / Float(totalTasks)
            }
        }

        // 导出社交媒体格式
        for platform in configuration.platforms {
            let fileName = "\(project.name)_\(platform.rawValue).mp4"
            let outputURL = outputDirectory.appendingPathComponent(fileName)

            await MainActor.run {
                currentStep = "正在导出 \(platform.rawValue) 格式..."
            }

            try await exportForSocialMedia(project: project, platform: platform, outputURL: outputURL)

            outputURLs.append(outputURL)
            completedTasks += 1

            await MainActor.run {
                progress = Float(completedTasks) / Float(totalTasks)
            }
        }

        // 导出 GIF
        if configuration.includeGIF, let gifConfig = configuration.gifConfig {
            let result = try await CompositionBuilder.buildComposition(from: project)
            let gifURL = outputDirectory.appendingPathComponent("\(project.name).gif")

            await MainActor.run {
                currentStep = "正在导出 GIF..."
            }

            try await exportGIF(from: result.composition, to: gifURL, configuration: gifConfig)

            outputURLs.append(gifURL)
        }

        await MainActor.run {
            isExporting = false
            progress = 1.0
            currentStep = "批量导出完成"
        }

        return outputURLs
    }
}

/// 高级导出错误
enum AdvancedExportError: LocalizedError {
    case failedToCreateDestination
    case failedToFinalize
    case failedToCreateSession
    case unknown

    var errorDescription: String? {
        switch self {
        case .failedToCreateDestination: return "无法创建输出文件"
        case .failedToFinalize: return "无法完成导出"
        case .failedToCreateSession: return "无法创建导出会话"
        case .unknown: return "未知错误"
        }
    }
}
