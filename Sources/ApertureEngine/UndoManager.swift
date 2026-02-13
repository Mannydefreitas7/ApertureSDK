import Foundation
import Combine
import AVFoundation

/// 编辑操作命令协议
protocol EditCommand {
    /// 执行操作
    func execute()

    /// 撤销操作
    func undo()

    /// 操作描述
    var description: String { get }
}

/// 编辑历史管理器
@MainActor
class EditHistoryManager: ObservableObject {

    /// 撤销栈
    @Published private(set) var undoStack: [EditCommand] = []

    /// 重做栈
    @Published private(set) var redoStack: [EditCommand] = []

    /// 最大历史记录数
    var maxHistorySize: Int = 50

    /// 是否可以撤销
    var canUndo: Bool { !undoStack.isEmpty }

    /// 是否可以重做
    var canRedo: Bool { !redoStack.isEmpty }

    /// 下一个撤销操作的描述
    var undoDescription: String? { undoStack.last?.description }

    /// 下一个重做操作的描述
    var redoDescription: String? { redoStack.last?.description }

    /// 执行命令
    func execute(_ command: EditCommand) {
        command.execute()
        undoStack.append(command)

        // 清空重做栈
        redoStack.removeAll()

        // 限制历史大小
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
    }

    /// 撤销
    func undo() {
        guard let command = undoStack.popLast() else { return }
        command.undo()
        redoStack.append(command)
    }

    /// 重做
    func redo() {
        guard let command = redoStack.popLast() else { return }
        command.execute()
        undoStack.append(command)
    }

    /// 清空历史
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}

// MARK: - 具体命令实现

/// 添加片段命令
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

    var description: String { "添加片段 \(clip.name)" }
}

/// 删除片段命令
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

    var description: String { "删除片段 \(clip.name)" }
}

/// 分割片段命令
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
            // 保存分割后的片段引用以便撤销
            if let track = engine.project.tracks.first(where: { $0.id == trackId }),
               let index = track.clips.firstIndex(where: { $0.id == originalClip.id }) {
                // 执行分割
                engine.splitClip(id: originalClip.id, at: splitTime)

                // 获取分割后的片段
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
            // 删除分割后的两个片段
            if let first = firstClip {
                engine.deleteClip(id: first.id)
            }
            if let second = secondClip {
                engine.deleteClip(id: second.id)
            }

            // 恢复原始片段
            engine.addClip(originalClip, to: trackId)
        }
    }

    var description: String { "分割片段 \(originalClip.name)" }
}

/// 移动片段命令
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

    var description: String { "移动片段" }
}

/// 修改片段属性命令
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

    var description: String { "修改片段 \(oldClip.name)" }
}

/// 添加轨道命令
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

    var description: String { "添加\(trackType == .video ? "视频" : "音频")轨道" }
}

/// 删除轨道命令
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
            // 恢复轨道
            engine.project.tracks.insert(track, at: min(trackIndex, engine.project.tracks.count))
        }
    }

    var description: String { "删除轨道 \(track.name)" }
}

/// 添加滤镜命令
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
        // TODO: 在 Clip 模型中添加 filter 属性后实现
    }

    func undo() {
        // TODO: 实现
    }

    var description: String { "添加滤镜 \(filter.type.displayName)" }
}

/// 添加文字命令
class AddTextCommand: EditCommand {
    private let engine: VideoEngine
    private let textOverlay: TextOverlay

    init(engine: VideoEngine, textOverlay: TextOverlay) {
        self.engine = engine
        self.textOverlay = textOverlay
    }

    func execute() {
        // TODO: 在 Project 模型中添加 textOverlays 属性后实现
    }

    func undo() {
        // TODO: 实现
    }

    var description: String { "添加文字" }
}

/// 复合命令（用于批量操作）
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
