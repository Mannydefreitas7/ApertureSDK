#if canImport(AVFoundation)
import Foundation
import AVFoundation

/// Handles audio processing operations
@available(iOS 15.0, macOS 12.0, *)
public class AudioProcessor {
    
    /// Extract audio from a video file
    /// - Parameters:
    ///   - videoURL: The video URL
    ///   - outputURL: The output audio URL
    ///   - format: The audio format (default: .m4a)
    /// - Throws: ApertureError if the operation fails
    public static func extractAudio(
        from videoURL: URL,
        outputURL: URL,
        format: AudioFormat = .m4a
    ) async throws {
        let asset = AVURLAsset(url: videoURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw ApertureError.exportFailed("Unable to create export session for \(asset.url)")
        }
        
        try await exportSession.export(to: outputURL, as: format.fileType)


    }
    
    /// Replace audio track in a video
    /// - Parameters:
    ///   - videoURL: The video URL
    ///   - audioURL: The new audio URL
    ///   - outputURL: The output URL
    /// - Throws: ApertureError if the operation fails
    public static func replaceAudio(
        in videoURL: URL,
        with audioURL: URL,
        outputURL: URL
    ) async throws {
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)

        let composition = AVMutableComposition()
        
        // Add video track
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ApertureError.exportFailed("Unable to add video track to composition")
        }
        
        // Add audio track
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ApertureError.exportFailed("Unable to add audio track to composition")
        }
        
        let videoDuration = try await videoAsset.load(.duration)
        let videoTimeRange = CMTimeRange(start: .zero, duration: videoDuration)
        
        // Insert video (without audio)
        if let sourceVideoTrack = try await videoAsset.loadTracks(withMediaType: .video).first {
            try videoTrack.insertTimeRange(videoTimeRange, of: sourceVideoTrack, at: .zero)
        }
        
        // Insert new audio
        if let sourceAudioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
            let audioDuration = try await audioAsset.load(.duration)
            let audioTimeRange = CMTimeRange(start: .zero, duration: min(audioDuration, videoDuration))
            try audioTrack.insertTimeRange(audioTimeRange, of: sourceAudioTrack, at: .zero)
        }
        
        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ApertureError.exportFailed("Unable to create export session for composition")
        }
        
        try await exportSession.export(to: outputURL, as: .mp4)
    }
    
    /// Trim audio to a specific time range
    /// - Parameters:
    ///   - inputURL: The input audio URL
    ///   - outputURL: The output URL
    ///   - startTime: The start time
    ///   - endTime: The end time
    /// - Throws: ApertureError if the operation fails
    public static func trimAudio(
        inputURL: URL,
        outputURL: URL,
        startTime: CMTime,
        endTime: CMTime
    ) async throws {
        let asset = AVURLAsset(url: inputURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw ApertureError.exportFailed("Unable to create export session for \(inputURL)")
        }

        exportSession.timeRange = CMTimeRange(start: startTime, end: endTime)
        
        try await exportSession.export(to: outputURL, as: .m4a)
    }
}

/// Audio format options
@available(iOS 15.0, macOS 12.0, *)
public enum AudioFormat {
    case m4a
    case mp3
    case wav
    
    var fileType: AVFileType {
        switch self {
        case .m4a:
            return .m4a
        case .mp3:
            return .mp3
        case .wav:
            return .wav
        }
    }
}
#endif
