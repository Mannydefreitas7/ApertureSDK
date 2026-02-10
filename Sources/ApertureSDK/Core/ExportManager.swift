#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Combine

/// Export preset configurations
@available(iOS 15.0, macOS 12.0, *)
public enum ExportPreset {
    case hd720p
    case hd1080p
    case hd4K
    case instagram
    case twitter
    case custom(width: Int, height: Int, bitrate: Int)
    
    var resolution: CGSize {
        switch self {
        case .hd720p:
            return CGSize(width: 1280, height: 720)
        case .hd1080p:
            return CGSize(width: 1920, height: 1080)
        case .hd4K:
            return CGSize(width: 3840, height: 2160)
        case .instagram:
            return CGSize(width: 1080, height: 1080)
        case .twitter:
            return CGSize(width: 1280, height: 720)
        case .custom(let width, let height, _):
            return CGSize(width: width, height: height)
        }
    }
    
    var bitrate: Int {
        switch self {
        case .hd720p:
            return 5_000_000
        case .hd1080p:
            return 8_000_000
        case .hd4K:
            return 20_000_000
        case .instagram:
            return 5_000_000
        case .twitter:
            return 5_000_000
        case .custom(_, _, let bitrate):
            return bitrate
        }
    }
}

/// Manages video export operations
@available(iOS 15.0, macOS 12.0, *)
public class ExportManager {
    private var currentExportSession: AVAssetExportSession?
    
    public init() {}
    
    /// Export a video project
    /// - Parameters:
    ///   - project: The video project to export
    ///   - preset: The export preset to use
    ///   - outputURL: The output URL
    ///   - progress: Optional progress callback
    /// - Throws: ApertureError if export fails
    public func export(project: VideoProject, preset: ExportPreset, outputURL: URL, progress: ((Double) -> Void)? = nil) async throws {
        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create composition
        let composition = try await createComposition(from: project)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ApertureError.exportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        self.currentExportSession = exportSession
        
        // Monitor progress
        if let progress = progress {
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                progress(Double(exportSession.progress))
            }
            
            defer {
                progressTimer.invalidate()
            }
            
            await exportSession.export()
        } else {
            await exportSession.export()
        }
        
        switch exportSession.status {
        case .completed:
            progress?(1.0)
            return
        case .failed:
            throw ApertureError.exportFailed
        case .cancelled:
            throw ApertureError.exportFailed
        default:
            throw ApertureError.exportFailed
        }
    }
    
    /// Cancel the current export operation
    public func cancelExport() {
        currentExportSession?.cancelExport()
        currentExportSession = nil
    }
    
    /// Create a composition from a video project
    private func createComposition(from project: VideoProject) async throws -> AVComposition {
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ApertureError.exportFailed
        }
        
        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ApertureError.exportFailed
        }
        
        var currentTime: CMTime = .zero
        
        // Add each asset to the composition
        for asset in project.assets {
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
        
        return composition
    }
}
#endif
