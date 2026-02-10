#if canImport(AVFoundation)
import Foundation
import AVFoundation

/// Handles audio mixing operations
@available(iOS 15.0, macOS 12.0, *)
public class AudioMixer {
    
    /// Mix background music with video audio
    /// - Parameters:
    ///   - videoURL: The video URL
    ///   - audioURL: The background music URL
    ///   - outputURL: The output URL
    ///   - videoVolume: Volume for video audio (0.0 to 1.0)
    ///   - musicVolume: Volume for background music (0.0 to 1.0)
    /// - Throws: ApertureError if the operation fails
    public static func mixAudio(
        videoURL: URL,
        backgroundMusicURL audioURL: URL,
        outputURL: URL,
        videoVolume: Float = 1.0,
        musicVolume: Float = 0.5
    ) async throws {
        let videoAsset = AVAsset(url: videoURL)
        let audioAsset = AVAsset(url: audioURL)
        
        let composition = AVMutableComposition()
        
        // Add video track
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ApertureError.exportFailed
        }
        
        // Add audio tracks
        guard let audioTrack1 = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ), let audioTrack2 = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ApertureError.exportFailed
        }
        
        let videoDuration = try await videoAsset.load(.duration)
        let videoTimeRange = CMTimeRange(start: .zero, duration: videoDuration)
        
        // Insert video
        if let sourceVideoTrack = try await videoAsset.loadTracks(withMediaType: .video).first {
            try videoTrack.insertTimeRange(videoTimeRange, of: sourceVideoTrack, at: .zero)
        }
        
        // Insert original audio
        if let sourceAudioTrack = try await videoAsset.loadTracks(withMediaType: .audio).first {
            try audioTrack1.insertTimeRange(videoTimeRange, of: sourceAudioTrack, at: .zero)
        }
        
        // Insert background music
        if let musicTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
            let musicDuration = try await audioAsset.load(.duration)
            let musicTimeRange = CMTimeRange(start: .zero, duration: min(musicDuration, videoDuration))
            try audioTrack2.insertTimeRange(musicTimeRange, of: musicTrack, at: .zero)
        }
        
        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ApertureError.exportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw ApertureError.exportFailed
        }
    }
    
    /// Adjust audio volume for a video
    /// - Parameters:
    ///   - inputURL: The input video URL
    ///   - outputURL: The output URL
    ///   - volume: The volume level (0.0 to 1.0)
    /// - Throws: ApertureError if the operation fails
    public static func adjustVolume(
        inputURL: URL,
        outputURL: URL,
        volume: Float
    ) async throws {
        let asset = AVAsset(url: inputURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ApertureError.exportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.audioMix = createAudioMix(for: asset, volume: volume)
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw ApertureError.exportFailed
        }
    }
    
    private static func createAudioMix(for asset: AVAsset, volume: Float) -> AVAudioMix {
        let audioMix = AVMutableAudioMix()
        var audioMixParams: [AVMutableAudioMixInputParameters] = []
        
        Task {
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            for track in audioTracks {
                let params = AVMutableAudioMixInputParameters(track: track)
                params.setVolume(volume, at: .zero)
                audioMixParams.append(params)
            }
        }
        
        audioMix.inputParameters = audioMixParams
        return audioMix
    }
}
#endif
