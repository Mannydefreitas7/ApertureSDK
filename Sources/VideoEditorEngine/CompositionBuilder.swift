#if canImport(AVFoundation)
import Foundation
import AVFoundation
import VideoEditorCore

/// Builds AVComposition from Core project timeline
@available(iOS 15.0, macOS 12.0, *)
public class CompositionBuilder {
    
    private let assetLoader: AssetLoader
    
    public init(assetLoader: AssetLoader = AssetLoader()) {
        self.assetLoader = assetLoader
    }
    
    /// Build an AVComposition from a project
    @MainActor
    public func buildComposition(from project: Project) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        
        for track in project.tracks {
            switch track.type {
            case .video:
                try await addVideoTrack(track, to: composition)
            case .audio:
                try await addAudioTrack(track, to: composition)
            case .overlay:
                // Overlays are handled in the rendering pipeline, not in composition
                break
            }
        }
        
        return composition
    }
    
    @MainActor
    private func addVideoTrack(_ track: Track, to composition: AVMutableComposition) async throws {
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoEditorError.exportFailed("Failed to create video track")
        }
        
        // Also add audio from video clips
        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        var currentTime: CMTime = .zero
        
        for clip in track.clips where clip.type == .video {
            guard let url = clip.sourceURL else { continue }
            
            let avAsset = try await assetLoader.loadAsset(from: url)
            let timeRange = CMTimeRange(
                start: CMTime(seconds: clip.timeRange.start, preferredTimescale: 600),
                duration: CMTime(seconds: clip.timeRange.duration, preferredTimescale: 600)
            )
            
            // Insert video
            let videoTracks = try await avAsset.loadTracks(withMediaType: .video)
            if let sourceVideoTrack = videoTracks.first {
                try compositionVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: currentTime)
            }
            
            // Insert audio from video
            if !clip.isMuted, let compositionAudioTrack = compositionAudioTrack {
                let audioTracks = try await avAsset.loadTracks(withMediaType: .audio)
                if let sourceAudioTrack = audioTracks.first {
                    try compositionAudioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
                }
            }
            
            currentTime = CMTimeAdd(currentTime, CMTime(seconds: clip.timeRange.duration, preferredTimescale: 600))
        }
    }
    
    @MainActor
    private func addAudioTrack(_ track: Track, to composition: AVMutableComposition) async throws {
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoEditorError.exportFailed("Failed to create audio track")
        }
        
        var currentTime: CMTime = .zero
        
        for clip in track.clips where clip.type == .audio {
            guard let url = clip.sourceURL else { continue }
            
            let avAsset = try await assetLoader.loadAsset(from: url)
            let timeRange = CMTimeRange(
                start: CMTime(seconds: clip.timeRange.start, preferredTimescale: 600),
                duration: CMTime(seconds: clip.timeRange.duration, preferredTimescale: 600)
            )
            
            let audioTracks = try await avAsset.loadTracks(withMediaType: .audio)
            if let sourceAudioTrack = audioTracks.first {
                try compositionAudioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
            }
            
            currentTime = CMTimeAdd(currentTime, CMTime(seconds: clip.timeRange.duration, preferredTimescale: 600))
        }
    }
}
#endif
