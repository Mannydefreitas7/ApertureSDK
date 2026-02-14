import Foundation
import AVFoundation

/// Composition Builder - Converts project to AVComposition
class CompositionBuilder {

    /// Build composition
    static func buildComposition(from project: Project) async throws -> CompositionResult {
        let composition = AVMutableComposition()
        let videoComposition = AVMutableVideoComposition()

        // Create composition tracks
        var compositionVideoTracks: [AVMutableCompositionTrack] = []
        var compositionAudioTracks: [AVMutableCompositionTrack] = []

        // Process video tracks
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

        // Process audio tracks
        for track in project.audioTracks where !track.isMuted {
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            compositionAudioTracks.append(compositionTrack)

            for clip in track.clips {
                try await insertClip(clip, into: compositionTrack, mediaType: .audio)
            }

            // Process audio from video clips
            for videoTrack in project.videoTracks where !videoTrack.isMuted {
                for clip in videoTrack.clips where clip.type == .video {
                    try await insertClip(clip, into: compositionTrack, mediaType: .audio)
                }
            }
        }

        // Configure video composition
        videoComposition.renderSize = project.settings.resolution.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(project.settings.frameRate))

        // Create video instruction
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

    /// Insert clip into track
    private static func insertClip(
        _ clip: Clip,
        into track: AVMutableCompositionTrack,
        mediaType: AVMediaType
    ) async throws {
        let assetTracks = try await clip.asset.loadTracks(withMediaType: mediaType)

        guard let assetTrack = assetTracks.first else {
            // If audio track but no audio, skip
            return
        }

        try track.insertTimeRange(
            clip.sourceTimeRange,
            of: assetTrack,
            at: clip.startTime
        )

        // Apply speed changes
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

    /// Build composition for preview only (may be partial clips)
    static func buildPreviewComposition(
        from project: Project,
        timeRange: CMTimeRange? = nil
    ) async throws -> CompositionResult {
        // For preview, use full build
        // Can be optimized later to build only required time range
        return try await buildComposition(from: project)
    }
}

/// Composition result
struct CompositionResult {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition

    /// Get AVAssetExportSession for export
    func makeExportSession(preset: String = AVAssetExportPresetHighestQuality) -> AVAssetExportSession? {
        let session = AVAssetExportSession(asset: composition, presetName: preset)
        session?.videoComposition = videoComposition
        return session
    }

    /// Get AVPlayerItem for playback
    func makePlayerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition
        return item
    }
}
