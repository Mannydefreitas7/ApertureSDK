import SwiftUI
import AVFoundation

/// 时间线视图
struct TimelineView: View {
    @EnvironmentObject var viewModel: EditorViewModel

    /// 每秒像素宽度
    @State private var pixelsPerSecond: CGFloat = 50

    /// 滚动偏移
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            // 时间线工具栏
            TimelineToolbar(pixelsPerSecond: $pixelsPerSecond)
                .frame(height: 36)

            Divider()

            // 时间线主体
            HStack(spacing: 0) {
                // 轨道头部
                VStack(spacing: 0) {
                    // 时间标尺占位
                    Color.clear
                        .frame(height: 24)

                    Divider()

                    // 轨道标签
                    ForEach(viewModel.engine.project.tracks) { track in
                        TrackHeader(track: track)
                            .frame(height: 60)
                        Divider()
                    }

                    Spacer()
                }
                .frame(width: 120)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // 时间线内容
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(spacing: 0) {
                        // 时间标尺
                        TimeRuler(
                            duration: viewModel.engine.project.duration,
                            pixelsPerSecond: pixelsPerSecond,
                            currentTime: viewModel.engine.currentTime
                        )
                        .frame(height: 24)

                        Divider()

                        // 轨道内容
                        ZStack(alignment: .topLeading) {
                            // 轨道背景
                            VStack(spacing: 0) {
                                ForEach(viewModel.engine.project.tracks) { track in
                                    TrackContent(
                                        track: track,
                                        pixelsPerSecond: pixelsPerSecond,
                                        selectedClipId: viewModel.engine.selectedClipId,
                                        onClipSelect: { clipId in
                                            viewModel.engine.selectedClipId = clipId
                                        }
                                    )
                                    .frame(height: 60)
                                    Divider()
                                }
                            }

                            // 播放头
                            PlayheadView(
                                currentTime: viewModel.engine.currentTime,
                                pixelsPerSecond: pixelsPerSecond,
                                height: CGFloat(viewModel.engine.project.tracks.count * 61)
                            )
                        }

                        Spacer()
                    }
                    .frame(minWidth: timelineWidth)
                }
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var timelineWidth: CGFloat {
        let durationSeconds = CMTimeGetSeconds(viewModel.engine.project.duration)
        return max(CGFloat(durationSeconds) * pixelsPerSecond + 200, 800)
    }
}

/// 时间线工具栏
struct TimelineToolbar: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @Binding var pixelsPerSecond: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            // 添加轨道
            Menu {
                Button("视频轨道") {
                    viewModel.engine.addTrack(type: .video)
                }
                Button("音频轨道") {
                    viewModel.engine.addTrack(type: .audio)
                }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)

            Divider()
                .frame(height: 20)

            // 编辑按钮
            Button(action: { viewModel.splitSelectedClip() }) {
                Image(systemName: "scissors")
            }
            .buttonStyle(.plain)
            .help("分割片段 (⌘B)")

            Button(action: { viewModel.deleteSelectedClip() }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .help("删除片段")

            Spacer()

            // 缩放控制
            HStack(spacing: 8) {
                Button(action: { pixelsPerSecond = max(10, pixelsPerSecond - 10) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.plain)

                Slider(value: $pixelsPerSecond, in: 10...200)
                    .frame(width: 100)

                Button(action: { pixelsPerSecond = min(200, pixelsPerSecond + 10) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
    }
}

/// 轨道头部
struct TrackHeader: View {
    let track: Track
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 8) {
            // 轨道图标
            Image(systemName: track.type == .video ? "film" : "waveform")
                .font(.caption)
                .foregroundColor(.secondary)

            // 轨道名称
            Text(track.name)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            // 控制按钮
            HStack(spacing: 4) {
                // 静音
                Button(action: {
                    viewModel.engine.toggleTrackMute(id: track.id)
                }) {
                    Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.fill")
                        .font(.caption)
                        .foregroundColor(track.isMuted ? .red : .secondary)
                }
                .buttonStyle(.plain)

                // 可见性（仅视频轨道）
                if track.type == .video {
                    Button(action: {
                        viewModel.engine.toggleTrackVisibility(id: track.id)
                    }) {
                        Image(systemName: track.isVisible ? "eye" : "eye.slash")
                            .font(.caption)
                            .foregroundColor(track.isVisible ? .secondary : .red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            viewModel.engine.selectedTrackId == track.id
                ? Color.accentColor.opacity(0.1)
                : Color.clear
        )
        .onTapGesture {
            viewModel.engine.selectedTrackId = track.id
        }
    }
}

/// 轨道内容
struct TrackContent: View {
    let track: Track
    let pixelsPerSecond: CGFloat
    let selectedClipId: UUID?
    let onClipSelect: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            // 背景网格
            TrackBackground()

            // 片段
            ForEach(track.clips) { clip in
                ClipView(
                    clip: clip,
                    pixelsPerSecond: pixelsPerSecond,
                    isSelected: selectedClipId == clip.id
                )
                .offset(x: CGFloat(CMTimeGetSeconds(clip.startTime)) * pixelsPerSecond)
                .onTapGesture {
                    onClipSelect(clip.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 轨道背景
struct TrackBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let gridSpacing: CGFloat = 50
                var x: CGFloat = 0
                while x < geometry.size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    x += gridSpacing
                }
            }
            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        }
    }
}

/// 片段视图
struct ClipView: View {
    let clip: Clip
    let pixelsPerSecond: CGFloat
    let isSelected: Bool

    var body: some View {
        let width = CGFloat(CMTimeGetSeconds(clip.duration)) * pixelsPerSecond

        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 4)
                .fill(clipColor)

            // 边框
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)

            // 内容
            HStack(spacing: 4) {
                // 缩略图
                if let thumbnail = clip.thumbnail {
                    Image(decorative: thumbnail, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipped()
                        .cornerRadius(2)
                }

                // 名称
                Text(clip.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()
            }
            .padding(4)
        }
        .frame(width: max(width, 40), height: 52)
    }

    private var clipColor: Color {
        switch clip.type {
        case .video: return Color.blue.opacity(0.8)
        case .audio: return Color.green.opacity(0.8)
        case .image: return Color.purple.opacity(0.8)
        }
    }
}

/// 时间标尺
struct TimeRuler: View {
    let duration: CMTime
    let pixelsPerSecond: CGFloat
    let currentTime: CMTime

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 刻度
                ForEach(0..<tickCount, id: \.self) { index in
                    let seconds = Double(index) * tickInterval
                    let x = CGFloat(seconds) * pixelsPerSecond

                    if x < geometry.size.width {
                        VStack(spacing: 2) {
                            // 刻度线
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: 1, height: index % majorTickInterval == 0 ? 10 : 5)

                            // 时间标签（仅主刻度）
                            if index % majorTickInterval == 0 {
                                Text(formatTime(seconds))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .offset(x: x)
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var tickInterval: Double {
        if pixelsPerSecond < 30 { return 5.0 }
        if pixelsPerSecond < 60 { return 2.0 }
        return 1.0
    }

    private var majorTickInterval: Int {
        if pixelsPerSecond < 30 { return 2 }
        if pixelsPerSecond < 60 { return 5 }
        return 5
    }

    private var tickCount: Int {
        let durationSeconds = CMTimeGetSeconds(duration)
        return Int(durationSeconds / tickInterval) + 20
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// 播放头
struct PlayheadView: View {
    let currentTime: CMTime
    let pixelsPerSecond: CGFloat
    let height: CGFloat

    var body: some View {
        let x = CGFloat(CMTimeGetSeconds(currentTime)) * pixelsPerSecond

        VStack(spacing: 0) {
            // 顶部三角形
            Triangle()
                .fill(Color.red)
                .frame(width: 12, height: 8)

            // 线
            Rectangle()
                .fill(Color.red)
                .frame(width: 2, height: height + 24)
        }
        .offset(x: x - 6, y: 0)
    }
}

/// 三角形
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}

#Preview {
    TimelineView()
        .environmentObject(EditorViewModel())
        .frame(width: 1000, height: 300)
}
