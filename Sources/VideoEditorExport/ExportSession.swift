#if canImport(AVFoundation)
import Foundation
import AVFoundation
import VideoEditorCore
import VideoEditorEngine

/// Export progress information
public struct ExportProgress: Sendable {
    public let fractionCompleted: Double
    public let estimatedTimeRemaining: Double?
    
    public init(fractionCompleted: Double, estimatedTimeRemaining: Double? = nil) {
        self.fractionCompleted = fractionCompleted
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}

/// Watermark configuration hook
public struct WatermarkConfig: Sendable {
    public let imageURL: URL?
    public let text: String?
    public let position: WatermarkPosition
    public let opacity: Double
    
    public enum WatermarkPosition: Sendable {
        case topLeft, topRight, bottomLeft, bottomRight, center
    }
    
    public init(
        imageURL: URL? = nil,
        text: String? = nil,
        position: WatermarkPosition = .bottomRight,
        opacity: Double = 0.5
    ) {
        self.imageURL = imageURL
        self.text = text
        self.position = position
        self.opacity = opacity
    }
}

/// Manages video export with progress reporting and cancellation
@available(iOS 15.0, macOS 12.0, *)
public class ExportSession {
    
    private let compositionBuilder: CompositionBuilder
    private var currentExportSession: AVAssetExportSession?
    private var isCancelled: Bool = false
    
    public init(compositionBuilder: CompositionBuilder = CompositionBuilder()) {
        self.compositionBuilder = compositionBuilder
    }
    
    /// Export a project with the given preset
    /// - Parameters:
    ///   - project: The project to export
    ///   - preset: Export preset configuration
    ///   - outputURL: The output file URL
    ///   - watermark: Optional watermark configuration
    ///   - progress: Progress callback
    public func export(
        project: Project,
        preset: ExportPreset,
        outputURL: URL,
        watermark: WatermarkConfig? = nil,
        progress: @escaping (ExportProgress) -> Void
    ) async throws {
        isCancelled = false
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Build composition from project
        let composition = try await compositionBuilder.buildComposition(from: project)
        
        // Determine AVFoundation preset
        let avPresetName: String
        switch preset.codec {
        case .h264:
            avPresetName = AVAssetExportPresetHighestQuality
        case .h265:
            if #available(iOS 17.0, macOS 14.0, *) {
                avPresetName = AVAssetExportPresetHEVCHighestQuality
            } else {
                avPresetName = AVAssetExportPresetHighestQuality
            }
        }
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: avPresetName
        ) else {
            throw VideoEditorError.exportFailed("Failed to create export session")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = preset.shouldOptimizeForNetworkUse
        
        self.currentExportSession = exportSession
        
        // Start progress monitoring
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, !self.isCancelled else { return }
            progress(ExportProgress(fractionCompleted: Double(exportSession.progress)))
        }
        
        defer {
            progressTimer.invalidate()
            self.currentExportSession = nil
        }
        
        // Check for cancellation
        guard !isCancelled else {
            throw VideoEditorError.cancelled
        }
        
        // Perform export
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            progress(ExportProgress(fractionCompleted: 1.0))
        case .cancelled:
            throw VideoEditorError.cancelled
        case .failed:
            throw VideoEditorError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        default:
            throw VideoEditorError.exportFailed("Export ended with unexpected status")
        }
    }
    
    /// Cancel the current export
    public func cancel() {
        isCancelled = true
        currentExportSession?.cancelExport()
        currentExportSession = nil
    }
}
#endif
