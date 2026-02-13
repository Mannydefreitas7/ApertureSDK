import Foundation
import AVFoundation
import Combine
import SwiftUI

/// 编辑器 ViewModel
@MainActor
class EditorViewModel: ObservableObject {

    /// 视频引擎
    @Published var engine: VideoEngine

    /// 媒体库中的素材
    @Published var mediaLibrary: [MediaItem] = []

    /// 是否显示导入面板
    @Published var showingImportPanel: Bool = false

    /// 是否显示导出面板
    @Published var showingExportPanel: Bool = false

    /// 是否显示项目设置
    @Published var showingProjectSettings: Bool = false

    /// 当前工具
    @Published var currentTool: EditorTool = .select

    /// 时间线视图模式
    @Published var timelineViewMode: TimelineViewMode = .full

    /// 当前显示的右侧面板
    @Published var rightPanelMode: RightPanelMode = .inspector

    /// 错误信息
    @Published var errorMessage: String?

    /// 是否显示错误
    @Published var showingError: Bool = false

    /// 编辑历史管理器
    let historyManager = EditHistoryManager()

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.engine = VideoEngine()
        setupBindings()
    }

    private func setupBindings() {
        // 监听引擎变化
        engine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - 媒体导入

    /// 导入媒体文件
    func importMedia(urls: [URL]) async {
        do {
            for url in urls {
                let clip = try await VideoImporter.importMedia(from: url)
                let mediaItem = MediaItem(
                    id: UUID(),
                    name: url.deletingPathExtension().lastPathComponent,
                    url: url,
                    type: clip.type,
                    duration: clip.duration,
                    thumbnail: clip.thumbnail
                )
                mediaLibrary.append(mediaItem)
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    /// 从媒体库添加到时间线
    func addToTimeline(mediaItem: MediaItem) async {
        do {
            let clip = try await VideoImporter.importMedia(from: mediaItem.url)

            // 找到合适的轨道
            let targetTrack: Track?
            switch clip.type {
            case .video:
                targetTrack = engine.project.videoTracks.first
            case .audio:
                targetTrack = engine.project.audioTracks.first
            case .image:
                targetTrack = engine.project.videoTracks.first
            }

            if let track = targetTrack {
                engine.addClip(clip, to: track.id)
                try await engine.preparePlayback()
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - 快捷操作

    /// 删除选中的片段
    func deleteSelectedClip() {
        guard let clipId = engine.selectedClipId else { return }
        engine.deleteClip(id: clipId)
    }

    /// 分割选中的片段
    func splitSelectedClip() {
        engine.splitSelectedClip()
    }

    /// 撤销
    func undo() {
        historyManager.undo()
        Task {
            try? await engine.preparePlayback()
        }
    }

    /// 重做
    func redo() {
        historyManager.redo()
        Task {
            try? await engine.preparePlayback()
        }
    }

    /// 是否可以撤销
    var canUndo: Bool { historyManager.canUndo }

    /// 是否可以重做
    var canRedo: Bool { historyManager.canRedo }

    // MARK: - 导出

    /// 导出视频
    func exportVideo(to url: URL, preset: VideoExporter.ExportPreset) async {
        do {
            try await engine.exportVideo(to: url, preset: preset)
        } catch {
            showError(error.localizedDescription)
        }
    }

    // MARK: - 时间格式化

    /// 格式化时间
    func formatTime(_ time: CMTime) -> String {
        let totalSeconds = CMTimeGetSeconds(time)
        guard totalSeconds.isFinite else { return "00:00:00" }

        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        let frames = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 30)

        if hours > 0 {
            return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
        } else {
            return String(format: "%02d:%02d:%02d", minutes, seconds, frames)
        }
    }

    // MARK: - 错误处理

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

/// 媒体库项目
struct MediaItem: Identifiable {
    let id: UUID
    let name: String
    let url: URL
    let type: ClipType
    let duration: CMTime
    let thumbnail: CGImage?

    var durationString: String {
        let seconds = CMTimeGetSeconds(duration)
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// 编辑工具
enum EditorTool: String, CaseIterable {
    case select = "选择"
    case cut = "切割"
    case trim = "裁剪"
    case text = "文字"
    case filter = "滤镜"
    case transition = "转场"

    var icon: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .cut: return "scissors"
        case .trim: return "crop"
        case .text: return "textformat"
        case .filter: return "camera.filters"
        case .transition: return "rectangle.on.rectangle"
        }
    }
}

/// 时间线视图模式
enum TimelineViewMode {
    case full       // 显示完整时间线
    case fit        // 适应窗口
    case custom     // 自定义缩放
}

/// 右侧面板模式
enum RightPanelMode: String, CaseIterable {
    case inspector = "属性"
    case filter = "滤镜"
    case text = "文字"
    case transition = "转场"
    case audio = "音频"
    case keyframe = "关键帧"
    case effects = "特效"
    case stickers = "贴纸"
    case ai = "AI"

    var icon: String {
        switch self {
        case .inspector: return "sidebar.right"
        case .filter: return "camera.filters"
        case .text: return "textformat"
        case .transition: return "rectangle.on.rectangle"
        case .audio: return "waveform"
        case .keyframe: return "slider.horizontal.below.square.and.square.filled"
        case .effects: return "sparkles"
        case .stickers: return "face.smiling"
        case .ai: return "brain"
        }
    }
}

// MARK: - 键盘快捷键
extension EditorViewModel {
    /// 处理键盘事件
    func handleKeyPress(_ key: KeyEquivalent, modifiers: EventModifiers) -> Bool {
        switch key {
        case " ":  // 空格 - 播放/暂停
            engine.togglePlayback()
            return true
        case "j":  // J - 后退
            engine.stepBackward(seconds: 5)
            return true
        case "k":  // K - 暂停
            engine.pause()
            return true
        case "l":  // L - 前进
            engine.stepForward(seconds: 5)
            return true
        case KeyEquivalent(Character(UnicodeScalar(127))):  // Delete
            deleteSelectedClip()
            return true
        default:
            return false
        }
    }
}
