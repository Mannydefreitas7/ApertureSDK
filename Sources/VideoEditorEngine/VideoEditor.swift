#if canImport(AVFoundation)
import Foundation
import AVFoundation
import VideoEditorCore

/// High-level video editing operations
@available(iOS 15.0, macOS 12.0, *)
public class VideoEditor {
    
    private let assetLoader: AssetLoader
    private let compositionBuilder: CompositionBuilder
    
    public init(assetLoader: AssetLoader = AssetLoader()) {
        self.assetLoader = assetLoader
        self.compositionBuilder = CompositionBuilder(assetLoader: assetLoader)
    }
    
    /// Trim and export a video file
    public func trimAndExport(
        inputURL: URL,
        outputURL: URL,
        startTime: Double,
        endTime: Double
    ) async throws {
        let asset = AVAsset(url: inputURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoEditorError.exportFailed("Failed to create export session")
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            end: CMTime(seconds: endTime, preferredTimescale: 600)
        )
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw VideoEditorError.exportFailed("Trim export failed")
        }
    }
    
    /// Split a video at specific time points
    public func split(
        inputURL: URL,
        at splitPoints: [Double],
        outputDirectory: URL,
        baseFileName: String = "segment"
    ) async throws -> [URL] {
        let asset = AVAsset(url: inputURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        
        let sortedPoints = splitPoints.sorted()
        
        var timeRanges: [(start: Double, end: Double)] = []
        var currentStart: Double = 0
        
        for point in sortedPoints {
            guard point > currentStart && point < totalSeconds else { continue }
            timeRanges.append((start: currentStart, end: point))
            currentStart = point
        }
        
        if currentStart < totalSeconds {
            timeRanges.append((start: currentStart, end: totalSeconds))
        }
        
        var outputURLs: [URL] = []
        
        for (index, range) in timeRanges.enumerated() {
            let outputURL = outputDirectory.appendingPathComponent("\(baseFileName)_\(index + 1).mp4")
            try await trimAndExport(inputURL: inputURL, outputURL: outputURL, startTime: range.start, endTime: range.end)
            outputURLs.append(outputURL)
        }
        
        return outputURLs
    }
    
    /// Merge multiple video URLs into one
    public func merge(urls: [URL], outputURL: URL) async throws {
        guard !urls.isEmpty else {
            throw VideoEditorError.invalidAsset
        }
        
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoEditorError.exportFailed("Failed to create video track")
        }
        
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        var currentTime: CMTime = .zero
        
        for url in urls {
            let avAsset = try await assetLoader.loadAsset(from: url)
            let duration = try await avAsset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            
            let videoTracks = try await avAsset.loadTracks(withMediaType: .video)
            if let sourceVideoTrack = videoTracks.first {
                try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: currentTime)
            }
            
            if let audioTrack = audioTrack {
                let audioTracks = try await avAsset.loadTracks(withMediaType: .audio)
                if let sourceAudioTrack = audioTracks.first {
                    try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
                }
            }
            
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoEditorError.exportFailed("Failed to create export session")
        }
        
        try? FileManager.default.removeItem(at: outputURL)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw VideoEditorError.exportFailed("Merge failed")
        }
    }
}
#endif
