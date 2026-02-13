import Foundation
import AVFoundation
import Combine

/// Video Engine - Core playback and editing control
@MainActor
class VideoEngine: ObservableObject {

    /// Current project
    @Published var project: Project

    /// Player
    @Published private(set) var player: AVPlayer?

    /// Current playback time
    @Published var currentTime: CMTime = .zero

    /// Whether currently playing
    @Published var isPlaying: Bool = false

    /// Currently selected clip
    @Published var selectedClipId: UUID?

    /// Currently selected track
    @Published var selectedTrackId: UUID?

    /// Timeline zoom scale
    @Published var timelineScale: Double = 1.0

    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    /// Exporter
    let exporter = VideoExporter()

    init(project: Project = Project()) {
        self.project = project
    }

    /// Clean up resources
    func cleanup() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        player = nil
    }

    // MARK: - 播放控制

    /// Prepare playback
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

    /// Play
    func play() {
        player?.play()
        isPlaying = true
    }

    /// Pause
    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// Toggle play/pause
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Seek to specified time
    func seek(to time: CMTime) {
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    /// Seek to beginning
    func seekToBeginning() {
        seek(to: .zero)
    }

    /// Seek to end
    func seekToEnd() {
        seek(to: project.duration)
    }

    /// Step forward by specified time
    func stepForward(seconds: Double = 1.0) {
        let newTime = CMTimeAdd(currentTime, CMTime(seconds: seconds, preferredTimescale: 600))
        let clampedTime = CMTimeMinimum(newTime, project.duration)
        seek(to: clampedTime)
    }

    /// Step backward by specified time
    func stepBackward(seconds: Double = 1.0) {
        let newTime = CMTimeSubtract(currentTime, CMTime(seconds: seconds, preferredTimescale: 600))
        let clampedTime = CMTimeMaximum(newTime, .zero)
        seek(to: clampedTime)
    }

    /// Setup time observer
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.03, preferredTimescale: 600) // ~30fps update

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

    /// Import media to specified track
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

        // Refresh playback
        try await preparePlayback()
    }

    /// Add clip to track
    func addClip(_ clip: Clip, to trackId: UUID) {
        guard var track = project.tracks.first(where: { $0.id == trackId }) else {
            return
        }

        var mutableClip = clip
        mutableClip.startTime = track.nextAvailableStartTime()
        track.addClip(mutableClip)

        project.updateTrack(track)
    }

    /// Delete clip
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

    /// Split clip
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

    /// Split selected clip at current time
    func splitSelectedClip() {
        guard let clipId = selectedClipId else { return }
        splitClip(id: clipId, at: currentTime)
    }

    /// Move clip
    func moveClip(id: UUID, to newStartTime: CMTime, trackId: UUID? = nil) {
        guard var sourceTrack = project.track(containingClip: id),
              let clipIndex = sourceTrack.clips.firstIndex(where: { $0.id == id }) else {
            return
        }

        var clip = sourceTrack.clips[clipIndex]
        clip.startTime = newStartTime

        if let targetTrackId = trackId, targetTrackId != sourceTrack.id {
            // Move to other track
            sourceTrack.removeClip(id: id)
            project.updateTrack(sourceTrack)

            if var targetTrack = project.tracks.first(where: { $0.id == targetTrackId }) {
                targetTrack.addClip(clip)
                project.updateTrack(targetTrack)
            }
        } else {
            // Move within same track
            sourceTrack.clips[clipIndex] = clip
            sourceTrack.sortClips()
            project.updateTrack(sourceTrack)
        }

        Task {
            try? await preparePlayback()
        }
    }

    // MARK: - 轨道操作

    /// Add track
    func addTrack(type: TrackType) {
        project.addTrack(type: type)
    }

    /// Delete track
    func deleteTrack(id: UUID) {
        project.removeTrack(id: id)

        if selectedTrackId == id {
            selectedTrackId = nil
        }

        Task {
            try? await preparePlayback()
        }
    }

    /// Toggle track mute
    func toggleTrackMute(id: UUID) {
        guard let index = project.tracks.firstIndex(where: { $0.id == id }) else {
            return
        }

        project.tracks[index].isMuted.toggle()

        Task {
            try? await preparePlayback()
        }
    }

    /// Toggle track visibility
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

    /// Export video
    func exportVideo(to url: URL, preset: VideoExporter.ExportPreset = .highest) async throws {
        let config = VideoExporter.ExportConfiguration(preset: preset)
        try await exporter.export(project: project, to: url, configuration: config)
    }
}
