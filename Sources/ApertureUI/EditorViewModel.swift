import Foundation
import AVFoundation
import Combine
import SwiftUI

/// Editor ViewModel
@MainActor
public class EditorViewModel: ObservableObject {

    /// Video engine
    @Published public var engine: VideoEngine

    /// Media library items
    @Published public var mediaLibrary: [MediaItem] = []

    /// Show import panel
    @Published public var showingImportPanel: Bool = false

    /// Show export panel
    @Published public var showingExportPanel: Bool = false

    /// Show project settings
    @Published public var showingProjectSettings: Bool = false

    /// Current tool
    @Published public var currentTool: EditorTool = .select

    /// Timeline view mode
    @Published public var timelineViewMode: TimelineViewMode = .full

    /// Right panel mode
    @Published public var rightPanelMode: RightPanelMode = .inspector

    /// Error message
    @Published public var errorMessage: String?

    /// Show error
    @Published public var showingError: Bool = false

    private var cancellables = Set<AnyCancellable>()

    public init() {
        self.engine = VideoEngine()
        setupBindings()
    }

    private func setupBindings() {
        engine.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Media Import

    public func importMedia(urls: [URL]) async {
        // Implementation for importing media
    }

    public func addToTimeline(mediaItem: MediaItem) async {
        // Implementation for adding to timeline
    }

    // MARK: - Quick Actions

    public func deleteSelectedClip() {
        guard let clipId = engine.selectedClipId else { return }
        // Implementation
    }

    public func splitSelectedClip() {
        // Implementation
    }

    public func undo() {
        // Implementation
    }

    public func redo() {
        // Implementation
    }

    public var canUndo: Bool { false }
    public var canRedo: Bool { false }

    // MARK: - Export

    public func exportVideo(to url: URL) async {
        // Implementation
    }

    // MARK: - Time Formatting

    public func formatTime(_ time: CMTime) -> String {
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

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

/// Media library item
public struct MediaItem: Identifiable {
    public let id: UUID
    public let name: String
    public let url: URL
    public let type: ClipType
    public let duration: CMTime
    public let thumbnail: CGImage?

    public var durationString: String {
        let seconds = CMTimeGetSeconds(duration)
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// Editor tool
public enum EditorTool: String, CaseIterable {
    case select = "Select"
    case cut = "Cut"
    case trim = "Trim"
    case text = "Text"
    case filter = "Filter"
    case transition = "Transition"

    public var icon: String {
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

/// Timeline view mode
public enum TimelineViewMode {
    case full
    case fit
    case custom
}

/// Right panel mode
public enum RightPanelMode: String, CaseIterable {
    case inspector = "Inspector"
    case filter = "Filter"
    case text = "Text"
    case transition = "Transition"
    case audio = "Audio"
    case keyframe = "Keyframe"
    case effects = "Effects"
    case stickers = "Stickers"
    case ai = "AI"

    public var icon: String {
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
