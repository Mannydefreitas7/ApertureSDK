#if canImport(AVFoundation)
import Foundation
import AVFoundation

/// Handles video splitting operations
@available(iOS 15.0, macOS 12.0, *)
public class VideoSplitter {
    
    /// Split a video at specific time points
    /// - Parameters:
    ///   - inputURL: The input video URL
    ///   - splitPoints: Array of time points where to split
    ///   - outputDirectory: Directory to save split segments
    ///   - baseFileName: Base name for output files
    /// - Returns: Array of URLs for the split segments
    /// - Throws: ApertureError if the operation fails
    public static func split(
        inputURL: URL,
        at splitPoints: [CMTime],
        outputDirectory: URL,
        baseFileName: String = "segment"
    ) async throws -> [URL] {
        let asset = AVAsset(url: inputURL)
        let duration = try await asset.load(.duration)
        
        // Sort split points
        let sortedPoints = splitPoints.sorted { CMTimeCompare($0, $1) < 0 }
        
        // Create time ranges for each segment
        var timeRanges: [CMTimeRange] = []
        var currentStart: CMTime = .zero
        
        for splitPoint in sortedPoints {
            guard CMTimeCompare(splitPoint, currentStart) > 0 && 
                  CMTimeCompare(splitPoint, duration) < 0 else {
                continue
            }
            
            let range = CMTimeRange(start: currentStart, end: splitPoint)
            timeRanges.append(range)
            currentStart = splitPoint
        }
        
        // Add final segment
        if CMTimeCompare(currentStart, duration) < 0 {
            let range = CMTimeRange(start: currentStart, end: duration)
            timeRanges.append(range)
        }
        
        // Export each segment
        var outputURLs: [URL] = []
        
        for (index, timeRange) in timeRanges.enumerated() {
            let outputURL = outputDirectory.appendingPathComponent("\(baseFileName)_\(index + 1).mp4")
            
            try? FileManager.default.removeItem(at: outputURL)
            
            guard let exportSession = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                throw ApertureError.exportFailed
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.timeRange = timeRange
            
            await exportSession.export()
            
            guard exportSession.status == .completed else {
                throw ApertureError.exportFailed
            }
            
            outputURLs.append(outputURL)
        }
        
        return outputURLs
    }
    
    /// Split a video into equal-length segments
    /// - Parameters:
    ///   - inputURL: The input video URL
    ///   - segmentCount: Number of segments to create
    ///   - outputDirectory: Directory to save split segments
    ///   - baseFileName: Base name for output files
    /// - Returns: Array of URLs for the split segments
    /// - Throws: ApertureError if the operation fails
    public static func splitIntoSegments(
        inputURL: URL,
        segmentCount: Int,
        outputDirectory: URL,
        baseFileName: String = "segment"
    ) async throws -> [URL] {
        guard segmentCount > 0 else {
            throw ApertureError.invalidTimeRange
        }
        
        let asset = AVAsset(url: inputURL)
        let duration = try await asset.load(.duration)
        let segmentDuration = CMTimeGetSeconds(duration) / Double(segmentCount)
        
        var splitPoints: [CMTime] = []
        for i in 1..<segmentCount {
            let time = CMTime(seconds: segmentDuration * Double(i), preferredTimescale: duration.timescale)
            splitPoints.append(time)
        }
        
        return try await split(
            inputURL: inputURL,
            at: splitPoints,
            outputDirectory: outputDirectory,
            baseFileName: baseFileName
        )
    }
}
#endif
