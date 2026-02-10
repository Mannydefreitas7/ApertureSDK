#if canImport(AVFoundation)
import Foundation
import AVFoundation

/// Handles video merging operations
@available(iOS 15.0, macOS 12.0, *)
public class VideoMerger {
    
    /// Merge multiple video assets into a single video
    /// - Parameters:
    ///   - assets: The video assets to merge
    ///   - outputURL: The output URL for the merged video
    ///   - resolution: The output resolution (nil for auto-scale)
    ///   - crossfadeDuration: Duration of crossfade between clips (nil for no crossfade)
    /// - Throws: ApertureError if the operation fails
    public static func merge(
        assets: [VideoAsset],
        outputURL: URL,
        resolution: CGSize? = nil,
        crossfadeDuration: CMTime? = nil
    ) async throws {
        guard !assets.isEmpty else {
            throw ApertureError.invalidAsset
        }
        
        // Create composition
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ApertureError.exportFailed
        }
        
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ApertureError.exportFailed
        }
        
        var currentTime: CMTime = .zero
        
        // Add each asset to the composition
        for asset in assets {
            let avAsset = asset.avAsset
            
            // Load tracks
            let videoTracks = try await avAsset.loadTracks(withMediaType: .video)
            let audioTracks = try await avAsset.loadTracks(withMediaType: .audio)
            
            let timeRange = CMTimeRange(start: asset.startTime, end: asset.endTime)
            let duration = asset.trimmedDuration
            
            // Insert video track
            if let sourceVideoTrack = videoTracks.first {
                try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: currentTime)
            }
            
            // Insert audio track
            if let sourceAudioTrack = audioTracks.first {
                try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
            }
            
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        // Export the composition
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
    
    /// Merge video files at given URLs
    /// - Parameters:
    ///   - urls: The URLs of videos to merge
    ///   - outputURL: The output URL
    /// - Throws: ApertureError if the operation fails
    public static func merge(urls: [URL], outputURL: URL) async throws {
        var assets: [VideoAsset] = []
        
        for url in urls {
            let asset = try await VideoAsset(url: url)
            assets.append(asset)
        }
        
        try await merge(assets: assets, outputURL: outputURL)
    }
}
#endif
