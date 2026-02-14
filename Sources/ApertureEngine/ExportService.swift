#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Combine


/// Manages video export operations
public actor ExportService {
    private var currentExportSession: AVAssetExportSession?
    static let shared = ExportService()
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
