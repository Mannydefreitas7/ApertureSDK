import Foundation
import AVFoundation

/// 视频导出器
class VideoExporter: ObservableObject {

    /// 导出进度 (0.0 - 1.0)
    @Published var progress: Float = 0

    /// 是否正在导出
    @Published var isExporting: Bool = false

    /// 导出状态
    @Published var status: ExportStatus = .idle

    private var exportSession: AVAssetExportSession?
    private var progressTimer: Timer?

    /// 导出预设
    enum ExportPreset {
        case low        // 640x480
        case medium     // 960x540
        case high       // 1280x720
        case highest    // 原始质量
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
            case .low: return "低质量 (480p)"
            case .medium: return "中等质量 (540p)"
            case .high: return "高质量 (720p)"
            case .highest: return "最高质量"
            case .h264_1080p: return "H.264 1080p"
            case .hevc_1080p: return "HEVC 1080p"
            }
        }
    }

    /// 导出配置
    struct ExportConfiguration {
        var preset: ExportPreset = .highest
        var fileType: AVFileType = .mp4
        var shouldOptimizeForNetworkUse: Bool = true
        var timeRange: CMTimeRange?
        var metadata: [AVMetadataItem]?

        static let `default` = ExportConfiguration()
    }

    /// 导出视频
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

        // 构建合成
        let result = try await CompositionBuilder.buildComposition(from: project)

        // 创建导出会话
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

        // 删除已存在的文件
        try? FileManager.default.removeItem(at: outputURL)

        await MainActor.run {
            status = .exporting
        }

        // 开始进度监控
        startProgressMonitoring()

        // 执行导出
        await session.export()

        // 停止进度监控
        stopProgressMonitoring()

        // 检查结果
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

    /// 取消导出
    func cancelExport() {
        exportSession?.cancelExport()
        stopProgressMonitoring()

        Task { @MainActor in
            status = .cancelled
            isExporting = false
        }
    }

    /// 开始进度监控
    private func startProgressMonitoring() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let session = self.exportSession else { return }
            Task { @MainActor in
                self.progress = session.progress
            }
        }
    }

    /// 停止进度监控
    private func stopProgressMonitoring() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    /// 获取可用的导出预设
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

    /// 估算输出文件大小
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

/// 导出状态
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

/// 导出错误
enum ExportError: LocalizedError {
    case failedToCreateSession
    case cancelled
    case unknown

    var errorDescription: String? {
        switch self {
        case .failedToCreateSession:
            return "无法创建导出会话"
        case .cancelled:
            return "导出已取消"
        case .unknown:
            return "未知错误"
        }
    }
}
