import Foundation
import AVFoundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// 视频导入器
class VideoImporter {

    /// 支持的视频格式
    static let supportedVideoTypes = ["mp4", "mov", "m4v", "avi", "mkv"]

    /// 支持的音频格式
    static let supportedAudioTypes = ["mp3", "m4a", "wav", "aac", "flac"]

    /// 支持的图片格式
    static let supportedImageTypes = ["jpg", "jpeg", "png", "heic", "gif"]

    /// 导入媒体文件
    static func importMedia(from url: URL) async throws -> Clip {
        let asset = AVAsset(url: url)

        // 加载资源属性
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)

        // 判断类型
        let type: ClipType
        let hasVideo = tracks.contains { $0.mediaType == .video }
        let hasAudio = tracks.contains { $0.mediaType == .audio }

        if hasVideo {
            type = .video
        } else if hasAudio {
            type = .audio
        } else {
            throw VideoImportError.unsupportedFormat
        }

        // 生成缩略图
        let thumbnail = try await generateThumbnail(for: asset, at: .zero)

        let clip = Clip(
            asset: asset,
            sourceURL: url,
            sourceTimeRange: CMTimeRange(start: .zero, duration: duration),
            startTime: .zero,
            type: type,
            name: url.deletingPathExtension().lastPathComponent
        )

        var mutableClip = clip
        mutableClip.thumbnail = thumbnail

        return mutableClip
    }

    /// 批量导入
    static func importMediaFiles(from urls: [URL]) async throws -> [Clip] {
        var clips: [Clip] = []

        for url in urls {
            do {
                let clip = try await importMedia(from: url)
                clips.append(clip)
            } catch {
                print("Failed to import \(url.lastPathComponent): \(error)")
            }
        }

        return clips
    }

    /// 生成缩略图
    static func generateThumbnail(for asset: AVAsset, at time: CMTime) async throws -> CGImage? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)

        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            return cgImage
        } catch {
            return nil
        }
    }

    /// 生成多个缩略图（用于时间线显示）
    static func generateThumbnails(
        for asset: AVAsset,
        count: Int
    ) async throws -> [CGImage] {
        let duration = try await asset.load(.duration)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 100, height: 60)

        var thumbnails: [CGImage] = []
        let interval = CMTimeGetSeconds(duration) / Double(count)

        for i in 0..<count {
            let time = CMTime(seconds: interval * Double(i), preferredTimescale: 600)
            if let image = try? generator.copyCGImage(at: time, actualTime: nil) {
                thumbnails.append(image)
            }
        }

        return thumbnails
    }

    /// 获取视频信息
    static func getMediaInfo(for url: URL) async throws -> MediaInfo {
        let asset = AVAsset(url: url)

        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)

        var videoSize: CGSize = .zero
        var frameRate: Float = 0

        if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
            videoSize = try await videoTrack.load(.naturalSize)
            frameRate = try await videoTrack.load(.nominalFrameRate)
        }

        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0

        return MediaInfo(
            duration: duration,
            videoSize: videoSize,
            frameRate: frameRate,
            fileSize: fileSize,
            url: url
        )
    }
}

/// 媒体信息
struct MediaInfo {
    let duration: CMTime
    let videoSize: CGSize
    let frameRate: Float
    let fileSize: Int64
    let url: URL

    var durationString: String {
        let seconds = CMTimeGetSeconds(duration)
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var resolutionString: String {
        "\(Int(videoSize.width))×\(Int(videoSize.height))"
    }
}

/// 导入错误
enum VideoImportError: LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case loadFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "文件不存在"
        case .unsupportedFormat:
            return "不支持的文件格式"
        case .loadFailed(let error):
            return "加载失败: \(error.localizedDescription)"
        }
    }
}
