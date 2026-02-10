#if canImport(AVFoundation)
import Foundation
import AVFoundation
import VideoEditorCore

/// Audio processing engine
@available(iOS 15.0, macOS 12.0, *)
public class AudioEngine {
    
    public init() {}
    
    /// Create audio mix parameters for volume control
    public func createAudioMix(for asset: AVAsset, volume: Float) async throws -> AVAudioMix {
        let audioMix = AVMutableAudioMix()
        var audioMixParams: [AVMutableAudioMixInputParameters] = []
        
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        for track in audioTracks {
            let params = AVMutableAudioMixInputParameters(track: track)
            params.setVolume(volume, at: .zero)
            audioMixParams.append(params)
        }
        
        audioMix.inputParameters = audioMixParams
        return audioMix
    }
    
    /// Create audio mix with fade in/out
    public func createAudioMixWithFade(
        for asset: AVAsset,
        volume: Float,
        fadeInDuration: Double = 0,
        fadeOutDuration: Double = 0
    ) async throws -> AVAudioMix {
        let audioMix = AVMutableAudioMix()
        var audioMixParams: [AVMutableAudioMixInputParameters] = []
        
        let duration = try await asset.load(.duration)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        
        for track in audioTracks {
            let params = AVMutableAudioMixInputParameters(track: track)
            
            // Set base volume
            params.setVolume(volume, at: .zero)
            
            // Fade in
            if fadeInDuration > 0 {
                let fadeInEnd = CMTime(seconds: fadeInDuration, preferredTimescale: 600)
                params.setVolumeRamp(fromStartVolume: 0, toEndVolume: volume,
                                     timeRange: CMTimeRange(start: .zero, duration: fadeInEnd))
            }
            
            // Fade out
            if fadeOutDuration > 0 {
                let fadeOutStart = CMTimeSubtract(duration, CMTime(seconds: fadeOutDuration, preferredTimescale: 600))
                params.setVolumeRamp(fromStartVolume: volume, toEndVolume: 0,
                                     timeRange: CMTimeRange(start: fadeOutStart, duration: CMTime(seconds: fadeOutDuration, preferredTimescale: 600)))
            }
            
            audioMixParams.append(params)
        }
        
        audioMix.inputParameters = audioMixParams
        return audioMix
    }
    
    /// Extract audio from a video file
    public func extractAudio(from videoURL: URL, outputURL: URL) async throws {
        let asset = AVAsset(url: videoURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw VideoEditorError.exportFailed("Failed to create export session")
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw VideoEditorError.exportFailed("Audio extraction failed")
        }
    }
}
#endif
