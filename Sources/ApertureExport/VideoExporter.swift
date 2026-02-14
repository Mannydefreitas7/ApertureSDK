import Foundation
import AVFoundation

/// Video exporter
class VideoExporter: ObservableObject {

    /// Export progress (0.0 - 1.0)
    @Published var progress: Float = 0

    /// Whether currently exporting
    @Published var isExporting: Bool = false

    /// Export status
    @Published var status: ExportStatus = .idle

    private var exportSession: AVAssetExportSession?
    private var progressTimer: Timer?

    /// Export presets
    enum ExportPreset {
        case low        // 640x480
        case medium     // 960x540
        case high       // 1280x720
        case highest    // Original quality
        case h264_1080p // H.264 1080p
        case hevc_1080p // HEVC 1080p

        var avPreset: String {
            switch self {
            case .low: return AVAssetExportPresetLowQuality
            case .medium: return AVAssetExportPresetMediumQuality
            case .high: return AVAssetExportPreset1280x720
            case .highest: return AVAssetExportPresetHighestQuality
            case .h264_1080p: return AVAssetExportPreset1920x1080
            case .hevc_1080p: return AVAssetExportPresetHEVC1920x1080
            }
        }

        var displayName: String {
            switch self {
            case .low: return "Low Quality (480p)"
            case .medium: return "Medium Quality (540p)"
            case .high: return "High Quality (720p)"
            case .highest: return "Highest Quality"
            case .h264_1080p: return "H.264 1080p"
            case .hevc_1080p: return "HEVC 1080p"
            }
        }
    }

    /// Export configuration
    struct ExportConfiguration {
        var preset: ExportPreset = .highest
        var fileType: AVFileType = .mp4
        var shouldOptimizeForNetworkUse: Bool = true
        var timeRange: CMTimeRange?
        var metadata: [AVMetadataItem]?

        static let `default` = ExportConfiguration()
    }

    /// Export video
    func export(
        project: Project,
        to outputURL: URL,
        configuration: ExportConfiguration = .default
    ) async throws {
        await MainActor.run {
            isExporting = true
            progress = 0
            status = .preparing
        }

        // Build composition
        let result = try await CompositionBuilder.buildComposition(from: project)

        // Create export session
        guard let session = result.makeExportSession(preset: configuration.preset.avPreset) else {
            throw ExportError.failedToCreateSession
        }

        exportSession = session
        session.outputURL = outputURL
        session.outputFileType = configuration.fileType
        session.shouldOptimizeForNetworkUse = configuration.shouldOptimizeForNetworkUse

        if let timeRange = configuration.timeRange {
            session.timeRange = timeRange
        }

        if let metadata = configuration.metadata {
            session.metadata = metadata
        }

        // Delete existing file
        try? FileManager.default.removeItem(at: outputURL)

        await MainActor.run {
            status = .exporting
        }

        // Start progress monitoring
        startProgressMonitoring()

        // Execute export
        await session.export()

        // Stop progress monitoring
        stopProgressMonitoring()

        // Check result
        switch session.status {
        case .completed:
            await MainActor.run {
                progress = 1.0
                status = .completed
                isExporting = false
            }
        case .failed:
            await MainActor.run {
                status = .failed(session.error ?? ExportError.unknown)
                isExporting = false
            }
            throw session.error ?? ExportError.unknown
        case .cancelled:
            await MainActor.run {
                status = .cancelled
                isExporting = false
            }
            throw ExportError.cancelled
        default:
            break
        }
    }

    /// Cancel export
    func cancelExport() {
        exportSession?.cancelExport()
        stopProgressMonitoring()

        Task { @MainActor in
            status = .cancelled
            isExporting = false
        }
    }

    /// Start progress monitoring
    private func startProgressMonitoring() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let session = self.exportSession else { return }
            Task { @MainActor in
                self.progress = session.progress
            }
        }
    }

    /// Stop progress monitoring
    private func stopProgressMonitoring() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    /// Get available export presets
    static func availablePresets(for asset: AVAsset) async -> [ExportPreset] {
        let allPresets: [ExportPreset] = [.low, .medium, .high, .highest, .h264_1080p, .hevc_1080p]
        var available: [ExportPreset] = []

        for preset in allPresets {
            let presetName = preset.avPreset
            if await AVAssetExportSession.compatibility(ofExportPreset: presetName, with: asset, outputFileType: .mp4) {
                available.append(preset)
            }
        }

        return available
    }

    /// Estimate output file size
    static func estimateFileSize(
        duration: CMTime,
        preset: ExportPreset
    ) -> Int64 {
        let seconds = CMTimeGetSeconds(duration)
        let bitratePerSecond: Int64

        switch preset {
        case .low: bitratePerSecond = 500_000         // 0.5 Mbps
        case .medium: bitratePerSecond = 2_000_000    // 2 Mbps
        case .high: bitratePerSecond = 5_000_000      // 5 Mbps
        case .highest: bitratePerSecond = 10_000_000  // 10 Mbps
        case .h264_1080p: bitratePerSecond = 8_000_000   // 8 Mbps
        case .hevc_1080p: bitratePerSecond = 6_000_000   // 6 Mbps
        }

        return Int64(seconds * Double(bitratePerSecond) / 8)
    }
}

/// Export status
enum ExportStatus: Equatable {
    case idle
    case preparing
    case exporting
    case completed
    case cancelled
    case failed(Error)

    static func == (lhs: ExportStatus, rhs: ExportStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.preparing, .preparing): return true
        case (.exporting, .exporting): return true
        case (.completed, .completed): return true
        case (.cancelled, .cancelled): return true
        case (.failed, .failed): return true
        default: return false
        }
    }
}

/// Export errors
enum ExportError: LocalizedError {
    case failedToCreateSession
    case cancelled
    case unknown

    var errorDescription: String? {
        switch self {
        case .failedToCreateSession:
            return "Failed to create export session"
        case .cancelled:
            return "Export cancelled"
        case .unknown:
            return "Unknown error"
        }
    }
}
