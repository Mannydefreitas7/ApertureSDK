#if canImport(AVFoundation)
import Foundation
import AVFoundation

/// Handles video trimming operations
@available(iOS 15.0, macOS 12.0, *)
public class VideoTrimmer {
    
    /// Trim a video asset to a specific time range
    /// - Parameters:
    ///   - asset: The video asset to trim
    ///   - startTime: The start time of the trim
    ///   - endTime: The end time of the trim
    /// - Throws: ApertureError if the operation fails
    public static func trim(asset: VideoAsset, startTime: CMTime, endTime: CMTime) throws {
        try asset.trim(start: startTime, end: endTime)
    }
    
    /// Trim a video file and export to a new URL
    /// - Parameters:
    ///   - inputURL: The input video URL
    ///   - outputURL: The output video URL
    ///   - startTime: The start time of the trim
    ///   - endTime: The end time of the trim
    /// - Throws: ApertureError if the operation fails
    public static func trimAndExport(
        inputURL: URL,
        outputURL: URL,
        startTime: CMTime,
        endTime: CMTime
    ) async throws {
        let asset = AVAsset(url: inputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw ApertureError.exportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.timeRange = CMTimeRange(start: startTime, end: endTime)
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw ApertureError.exportFailed
        }
    }
}
#endif
