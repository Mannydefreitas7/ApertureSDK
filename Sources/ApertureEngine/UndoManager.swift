import Foundation
import Combine
import AVFoundation

/// Edit operation command protocol
protocol EditCommand {
    /// Execute operation
    func execute()

    /// Undo operation
    func undo()

    /// Operation description
    var description: String { get }
}

/// Edit history manager
@MainActor
class EditHistoryManager: ObservableObject {

    /// Undo stack
    @Published private(set) var undoStack: [EditCommand] = []

    /// Redo stack
    @Published private(set) var redoStack: [EditCommand] = []

    /// Maximum history count
    var maxHistorySize: Int = 50

    /// Whether can undo
    var canUndo: Bool { !undoStack.isEmpty }

    /// Whether can redo
    var canRedo: Bool { !redoStack.isEmpty }

    /// Description of next undo operation
    var undoDescription: String? { undoStack.last?.description }

    /// Description of next redo operation
    var redoDescription: String? { redoStack.last?.description }

    /// Execute command
    func execute(_ command: EditCommand) {
        command.execute()
        undoStack.append(command)

        // Clear redo stack
        redoStack.removeAll()

        // Limit history size
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
    }

    /// Undo
    func undo() {
        guard let command = undoStack.popLast() else { return }
        command.undo()
        redoStack.append(command)
    }

    /// Redo
    func redo() {
        guard let command = redoStack.popLast() else { return }
        command.execute()
        undoStack.append(command)
    }

    /// Clear history
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}

// MARK: - Concrete Command Implementations

/// Add clip command
class AddClipCommand: EditCommand {
    private let engine: VideoEngine
    private let clip: Clip
    private let trackId: UUID

    init(engine: VideoEngine, clip: Clip, trackId: UUID) {
        self.engine = engine
        self.clip = clip
        self.trackId = trackId
    }

    func execute() {
        Task { @MainActor in
            engine.addClip(clip, to: trackId)
        }
    }

    func undo() {
        Task { @MainActor in
            engine.deleteClip(id: clip.id)
        }
    }

    var description: String { "Add clip \(clip.name)" }
}

/// Delete clip command
class DeleteClipCommand: EditCommand {
    private let engine: VideoEngine
    private let clip: Clip
    private let trackId: UUID

    init(engine: VideoEngine, clip: Clip, trackId: UUID) {
        self.engine = engine
        self.clip = clip
        self.trackId = trackId
    }

    func execute() {
        Task { @MainActor in
            engine.deleteClip(id: clip.id)
        }
    }

    func undo() {
        Task { @MainActor in
            engine.addClip(clip, to: trackId)
        }
    }

    var description: String { "Delete clip \(clip.name)" }
}

/// Split clip command
class SplitClipCommand: EditCommand {
    private let engine: VideoEngine
    private let originalClip: Clip
    private let trackId: UUID
    private let splitTime: CMTime
    private var firstClip: Clip?
    private var secondClip: Clip?

    init(engine: VideoEngine, clip: Clip, trackId: UUID, at time: CMTime) {
        self.engine = engine
        self.originalClip = clip
        self.trackId = trackId
        self.splitTime = time
    }

    func execute() {
        Task { @MainActor in
            // Save split clip references for undo
            if let track = engine.project.tracks.first(where: { $0.id == trackId }),
               let index = track.clips.firstIndex(where: { $0.id == originalClip.id }) {
                // Execute split
                engine.splitClip(id: originalClip.id, at: splitTime)

                // Get split clips
                if let updatedTrack = engine.project.tracks.first(where: { $0.id == trackId }) {
                    if index < updatedTrack.clips.count {
                        firstClip = updatedTrack.clips[index]
                    }
                    if index + 1 < updatedTrack.clips.count {
                        secondClip = updatedTrack.clips[index + 1]
                    }
                }
            }
        }
    }

    func undo() {
        Task { @MainActor in
            // Delete the two split clips
            if let first = firstClip {
                engine.deleteClip(id: first.id)
            }
            if let second = secondClip {
                engine.deleteClip(id: second.id)
            }

            // Restore original clip
            engine.addClip(originalClip, to: trackId)
        }
    }

    var description: String { "Split clip \(originalClip.name)" }
}

/// Move clip command
class MoveClipCommand: EditCommand {
    private let engine: VideoEngine
    private let clipId: UUID
    private let fromTrackId: UUID
    private let toTrackId: UUID
    private let fromStartTime: CMTime
    private let toStartTime: CMTime

    init(engine: VideoEngine, clipId: UUID, fromTrackId: UUID, toTrackId: UUID, fromStartTime: CMTime, toStartTime: CMTime) {
        self.engine = engine
        self.clipId = clipId
        self.fromTrackId = fromTrackId
        self.toTrackId = toTrackId
        self.fromStartTime = fromStartTime
        self.toStartTime = toStartTime
    }

    func execute() {
        Task { @MainActor in
            engine.moveClip(id: clipId, to: toStartTime, trackId: toTrackId)
        }
    }

    func undo() {
        Task { @MainActor in
            engine.moveClip(id: clipId, to: fromStartTime, trackId: fromTrackId)
        }
    }

    var description: String { "Move clip" }
}

/// Modify clip properties command
class ModifyClipCommand: EditCommand {
    private let engine: VideoEngine
    private let clipId: UUID
    private let trackId: UUID
    private let oldClip: Clip
    private let newClip: Clip

    init(engine: VideoEngine, trackId: UUID, oldClip: Clip, newClip: Clip) {
        self.engine = engine
        self.clipId = oldClip.id
        self.trackId = trackId
        self.oldClip = oldClip
        self.newClip = newClip
    }

    func execute() {
        Task { @MainActor in
            if var track = engine.project.tracks.first(where: { $0.id == trackId }),
               let index = track.clips.firstIndex(where: { $0.id == clipId }) {
                track.clips[index] = newClip
                engine.project.updateTrack(track)
            }
        }
    }

    func undo() {
        Task { @MainActor in
            if var track = engine.project.tracks.first(where: { $0.id == trackId }),
               let index = track.clips.firstIndex(where: { $0.id == clipId }) {
                track.clips[index] = oldClip
                engine.project.updateTrack(track)
            }
        }
    }

    var description: String { "Modify clip \(oldClip.name)" }
}

/// Add track command
class AddTrackCommand: EditCommand {
    private let engine: VideoEngine
    private let trackType: TrackType
    private var addedTrackId: UUID?

    init(engine: VideoEngine, type: TrackType) {
        self.engine = engine
        self.trackType = type
    }

    func execute() {
        Task { @MainActor in
            let countBefore = engine.project.tracks.count
            engine.addTrack(type: trackType)
            if engine.project.tracks.count > countBefore {
                addedTrackId = engine.project.tracks.last?.id
            }
        }
    }

    func undo() {
        Task { @MainActor in
            if let trackId = addedTrackId {
                engine.deleteTrack(id: trackId)
            }
        }
    }

    var description: String { "Add \(trackType == .video ? "video" : "audio") track" }
}

/// Delete track command
class DeleteTrackCommand: EditCommand {
    private let engine: VideoEngine
    private let track: Track
    private let trackIndex: Int

    init(engine: VideoEngine, track: Track, index: Int) {
        self.engine = engine
        self.track = track
        self.trackIndex = index
    }

    func execute() {
        Task { @MainActor in
            engine.deleteTrack(id: track.id)
        }
    }

    func undo() {
        Task { @MainActor in
            // Restore track
            engine.project.tracks.insert(track, at: min(trackIndex, engine.project.tracks.count))
        }
    }

    var description: String { "Delete track \(track.name)" }
}

/// Add filter command
class AddFilterCommand: EditCommand {
    private let engine: VideoEngine
    private let clipId: UUID
    private let trackId: UUID
    private let filter: VideoFilter

    init(engine: VideoEngine, trackId: UUID, clipId: UUID, filter: VideoFilter) {
        self.engine = engine
        self.trackId = trackId
        self.clipId = clipId
        self.filter = filter
    }

    func execute() {
        // TODO: Implement after adding filter property to Clip model
    }

    func undo() {
        // TODO: Implement
    }

    var description: String { "Add filter \(filter.type.displayName)" }
}

/// Add text command
class AddTextCommand: EditCommand {
    private let engine: VideoEngine
    private let textOverlay: TextOverlay

    init(engine: VideoEngine, textOverlay: TextOverlay) {
        self.engine = engine
        self.textOverlay = textOverlay
    }

    func execute() {
        // TODO: Implement after adding textOverlays property to Project model
    }

    func undo() {
        // TODO: Implement
    }

    var description: String { "Add text" }
}

/// Compound command (for batch operations)
class CompoundCommand: EditCommand {
    private let commands: [EditCommand]
    private let name: String

    init(name: String, commands: [EditCommand]) {
        self.name = name
        self.commands = commands
    }

    func execute() {
        for command in commands {
            command.execute()
        }
    }

    func undo() {
        for command in commands.reversed() {
            command.undo()
        }
    }

    var description: String { name }
}
