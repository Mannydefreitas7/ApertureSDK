import Foundation
import AVFoundation
import Combine

/// 视频引擎 - 核心播放和编辑控制
@MainActor
class VideoEngine: ObservableObject {

    /// 当前项目
    @Published var project: Project

    /// 播放器
    @Published private(set) var player: AVPlayer?

    /// 当前播放时间
    @Published var currentTime: CMTime = .zero

    /// 是否正在播放
    @Published var isPlaying: Bool = false

    /// 当前选中的片段
    @Published var selectedClipId: UUID?

    /// 当前选中的轨道
    @Published var selectedTrackId: UUID?

    /// 时间线缩放比例
    @Published var timelineScale: Double = 1.0

    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    /// 导出器
    let exporter = VideoExporter()

    init(project: Project = Project()) {
        self.project = project
    }

    /// 清理资源
    func cleanup() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        player = nil
    }

    // MARK: - 播放控制

    /// 准备播放
    func preparePlayback() async throws {
        let result = try await CompositionBuilder.buildComposition(from: project)
        let item = result.makePlayerItem()

        playerItem = item

        if player == nil {
            player = AVPlayer(playerItem: item)
            setupTimeObserver()
        } else {
            player?.replaceCurrentItem(with: item)
        }
    }

    /// 播放
    func play() {
        player?.play()
        isPlaying = true
    }

    /// 暂停
    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// 切换播放/暂停
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// 跳转到指定时间
    func seek(to time: CMTime) {
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    /// 跳转到开头
    func seekToBeginning() {
        seek(to: .zero)
    }

    /// 跳转到结尾
    func seekToEnd() {
        seek(to: project.duration)
    }

    /// 前进指定时间
    func stepForward(seconds: Double = 1.0) {
        let newTime = CMTimeAdd(currentTime, CMTime(seconds: seconds, preferredTimescale: 600))
        let clampedTime = CMTimeMinimum(newTime, project.duration)
        seek(to: clampedTime)
    }

    /// 后退指定时间
    func stepBackward(seconds: Double = 1.0) {
        let newTime = CMTimeSubtract(currentTime, CMTime(seconds: seconds, preferredTimescale: 600))
        let clampedTime = CMTimeMaximum(newTime, .zero)
        seek(to: clampedTime)
    }

    /// 设置时间观察器
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.03, preferredTimescale: 600) // ~30fps 更新

        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time
            }
        }
    }

    // MARK: - 编辑操作

    /// 导入媒体到指定轨道
    func importMedia(from urls: [URL], to trackId: UUID) async throws {
        let clips = try await VideoImporter.importMediaFiles(from: urls)

        guard var track = project.tracks.first(where: { $0.id == trackId }) else {
            return
        }

        for var clip in clips {
            clip.startTime = track.nextAvailableStartTime()
            track.addClip(clip)
        }

        project.updateTrack(track)

        // 刷新播放
        try await preparePlayback()
    }

    /// 添加片段到轨道
    func addClip(_ clip: Clip, to trackId: UUID) {
        guard var track = project.tracks.first(where: { $0.id == trackId }) else {
            return
        }

        var mutableClip = clip
        mutableClip.startTime = track.nextAvailableStartTime()
        track.addClip(mutableClip)

        project.updateTrack(track)
    }

    /// 删除片段
    func deleteClip(id: UUID) {
        guard var track = project.track(containingClip: id) else {
            return
        }

        track.removeClip(id: id)
        project.updateTrack(track)

        if selectedClipId == id {
            selectedClipId = nil
        }

        Task {
            try? await preparePlayback()
        }
    }

    /// 分割片段
    func splitClip(id: UUID, at time: CMTime) {
        guard var track = project.track(containingClip: id),
              let clipIndex = track.clips.firstIndex(where: { $0.id == id }),
              let (first, second) = track.clips[clipIndex].split(at: time) else {
            return
        }

        track.clips[clipIndex] = first
        track.clips.insert(second, at: clipIndex + 1)

        project.updateTrack(track)

        Task {
            try? await preparePlayback()
        }
    }

    /// 在当前时间分割选中的片段
    func splitSelectedClip() {
        guard let clipId = selectedClipId else { return }
        splitClip(id: clipId, at: currentTime)
    }

    /// 移动片段
    func moveClip(id: UUID, to newStartTime: CMTime, trackId: UUID? = nil) {
        guard var sourceTrack = project.track(containingClip: id),
              let clipIndex = sourceTrack.clips.firstIndex(where: { $0.id == id }) else {
            return
        }

        var clip = sourceTrack.clips[clipIndex]
        clip.startTime = newStartTime

        if let targetTrackId = trackId, targetTrackId != sourceTrack.id {
            // 移动到其他轨道
            sourceTrack.removeClip(id: id)
            project.updateTrack(sourceTrack)

            if var targetTrack = project.tracks.first(where: { $0.id == targetTrackId }) {
                targetTrack.addClip(clip)
                project.updateTrack(targetTrack)
            }
        } else {
            // 在同一轨道移动
            sourceTrack.clips[clipIndex] = clip
            sourceTrack.sortClips()
            project.updateTrack(sourceTrack)
        }

        Task {
            try? await preparePlayback()
        }
    }

    // MARK: - 轨道操作

    /// 添加轨道
    func addTrack(type: TrackType) {
        project.addTrack(type: type)
    }

    /// 删除轨道
    func deleteTrack(id: UUID) {
        project.removeTrack(id: id)

        if selectedTrackId == id {
            selectedTrackId = nil
        }

        Task {
            try? await preparePlayback()
        }
    }

    /// 切换轨道静音
    func toggleTrackMute(id: UUID) {
        guard let index = project.tracks.firstIndex(where: { $0.id == id }) else {
            return
        }

        project.tracks[index].isMuted.toggle()

        Task {
            try? await preparePlayback()
        }
    }

    /// 切换轨道可见性
    func toggleTrackVisibility(id: UUID) {
        guard let index = project.tracks.firstIndex(where: { $0.id == id }) else {
            return
        }

        project.tracks[index].isVisible.toggle()

        Task {
            try? await preparePlayback()
        }
    }

    // MARK: - 导出

    /// 导出视频
    func exportVideo(to url: URL, preset: VideoExporter.ExportPreset = .highest) async throws {
        let config = VideoExporter.ExportConfiguration(preset: preset)
        try await exporter.export(project: project, to: url, configuration: config)
    }
}
