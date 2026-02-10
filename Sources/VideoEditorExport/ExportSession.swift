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

/// Manages video export with progress reporting and cancellation
@available(iOS 15.0, macOS 12.0, *)
public actor ExportSession {
    
    private let compositionBuilder: CompositionBuilder
    private var currentExportSession: AVAssetExportSession?
    private var isCancelled: Bool = false
    
    /// Progress polling interval in nanoseconds (0.1 seconds)
    private static let progressPollingInterval: UInt64 = 100_000_000
    
    public init(compositionBuilder: CompositionBuilder = CompositionBuilder()) {
        self.compositionBuilder = compositionBuilder
    }
    
    /// Export a project with the given preset
    /// - Parameters:
    ///   - project: The project to export
    ///   - preset: Export preset configuration
    ///   - outputURL: The output file URL
    ///   - progress: Progress callback. Marked `@Sendable` because it is called from
    ///     the actor's context — wrap UI updates in `Task { @MainActor in … }`.
    public func export(
        project: Project,
        preset: ExportPreset,
        outputURL: URL,
        progress: @escaping @Sendable (ExportProgress) -> Void
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
                throw VideoEditorError.exportFailed("H.265 codec is not available on this OS version")
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
        
        // Start Task-based progress monitoring
        let progressTask = Task { [weak exportSession] in
            while let session = exportSession, session.status == .exporting || session.status == .waiting {
                progress(ExportProgress(fractionCompleted: Double(session.progress)))
                try? await Task.sleep(nanoseconds: ExportSession.progressPollingInterval)
            }
        }
        
        defer {
            progressTask.cancel()
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
