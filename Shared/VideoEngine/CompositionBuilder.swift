import Foundation
import AVFoundation

/// 合成构建器 - 将项目转换为 AVComposition
class CompositionBuilder {

    /// 构建合成
    static func buildComposition(from project: Project) async throws -> CompositionResult {
        let composition = AVMutableComposition()
        let videoComposition = AVMutableVideoComposition()

        // 创建合成轨道
        var compositionVideoTracks: [AVMutableCompositionTrack] = []
        var compositionAudioTracks: [AVMutableCompositionTrack] = []

        // 处理视频轨道
        for track in project.videoTracks where !track.isMuted && track.isVisible {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            compositionVideoTracks.append(compositionTrack)

            for clip in track.clips {
                try await insertClip(clip, into: compositionTrack, mediaType: .video)
            }
        }

        // 处理音频轨道
        for track in project.audioTracks where !track.isMuted {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            compositionAudioTracks.append(compositionTrack)

            for clip in track.clips {
                try await insertClip(clip, into: compositionTrack, mediaType: .audio)
            }

            // 处理视频片段中的音频
            for videoTrack in project.videoTracks where !videoTrack.isMuted {
                for clip in videoTrack.clips where clip.type == .video {
                    try await insertClip(clip, into: compositionTrack, mediaType: .audio)
                }
            }
        }

        // 配置视频合成
        videoComposition.renderSize = project.settings.resolution.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(project.settings.frameRate))

        // 创建视频指令
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: project.duration)

        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        for track in compositionVideoTracks {
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            layerInstructions.append(layerInstruction)
        }

        instruction.layerInstructions = layerInstructions
        videoComposition.instructions = [instruction]

        return CompositionResult(
            composition: composition,
            videoComposition: videoComposition
        )
    }

    /// 插入片段到轨道
    private static func insertClip(
        _ clip: Clip,
        into track: AVMutableCompositionTrack,
        mediaType: AVMediaType
    ) async throws {
        let assetTracks = try await clip.asset.loadTracks(withMediaType: mediaType)

        guard let assetTrack = assetTracks.first else {
            // 如果是音频轨道但没有音频，跳过
            return
        }

        try track.insertTimeRange(
            clip.sourceTimeRange,
            of: assetTrack,
            at: clip.startTime
        )

        // 应用速度变化
        if clip.speed != 1.0 {
            let scaledDuration = CMTimeMultiplyByFloat64(
                clip.sourceTimeRange.duration,
                multiplier: Float64(1.0 / clip.speed)
            )
            track.scaleTimeRange(
                CMTimeRange(start: clip.startTime, duration: clip.sourceTimeRange.duration),
                toDuration: scaledDuration
            )
        }
    }

    /// 构建仅用于预览的合成（可能是部分片段）
    static func buildPreviewComposition(
        from project: Project,
        timeRange: CMTimeRange? = nil
    ) async throws -> CompositionResult {
        // 对于预览，使用完整构建
        // 后续可以优化为只构建需要的时间范围
        return try await buildComposition(from: project)
    }
}

/// 合成结果
struct CompositionResult {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition

    /// 获取用于导出的 AVAssetExportSession
    func makeExportSession(preset: String = AVAssetExportPresetHighestQuality) -> AVAssetExportSession? {
        let session = AVAssetExportSession(asset: composition, presetName: preset)
        session?.videoComposition = videoComposition
        return session
    }

    /// 获取用于播放的 AVPlayerItem
    func makePlayerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition
        return item
    }
}
