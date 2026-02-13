#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Combine

/// Export preset configurations
public enum ExportPreset: Sendable {
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
public actor ExportManager {
    private var currentExportSession: AVAssetExportSession?
    static let shared = ExportManager()
    var progress: Double?

    private init() {}

    /// Export a video project
    /// - Parameters:
    ///   - project: The video project to export
    ///   - preset: The export preset to use
    ///   - outputURL: The output URL
    ///   - progress: Optional progress callback
    /// - Throws: ApertureError if export fails
    public func export(project: VideoProject, preset: ExportPreset, outputURL: URL) async throws -> Double? {
        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create composition
        let composition = try await createComposition(from: project)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ApertureError.exportFailed("")
        }
        
        exportSession.shouldOptimizeForNetworkUse = true
        
        self.currentExportSession = exportSession
        let exportProgress = exportSession.states(updateInterval: 0.1)
        try await exportSession.export(to: outputURL, as: .mp4)

            // You can also monitor progress:
        for await state in exportSession.states(updateInterval: 0.1) {
            switch state {
                case .pending: break
                case .exporting(let completed):
                    print("Progress:", completed.fractionCompleted)
                    progress = completed.fractionCompleted
                case .waiting: break
                default:
                    throw ApertureError.exportFailed("export for \(outputURL) failed")
            }
        }
        return progress
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
            throw ApertureError.exportFailed("")
        }
        
        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ApertureError.exportFailed("")
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
