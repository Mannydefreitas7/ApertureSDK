import SwiftUI
import AVKit

/// iOS 编辑视图
struct iOSEditorView: View {
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 预览区域
                iOSPreviewView()
                    .frame(height: geometry.size.height * 0.5)

                // 工具栏
                iOSToolbar()
                    .frame(height: 60)

                // 时间线
                iOSTimelineView()
                    .frame(maxHeight: .infinity)
            }
        }
    }
}

/// iOS 预览视图
struct iOSPreviewView: View {
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        ZStack {
            Color.black

            if let player = viewModel.engine.player {
                VideoPlayer(player: player)
                    .disabled(true)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("添加视频以开始")
                        .foregroundColor(.gray)
                }
            }

            // 播放控制覆盖层
            VStack {
                Spacer()

                iOSPlaybackOverlay()
                    .padding(.bottom, 20)
            }
        }
    }
}

/// iOS 播放控制覆盖层
struct iOSPlaybackOverlay: View {
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 12) {
            // 时间显示
            Text(viewModel.formatTime(viewModel.engine.currentTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)

            // 播放按钮
            HStack(spacing: 40) {
                Button(action: { viewModel.engine.stepBackward(seconds: 5) }) {
                    Image(systemName: "gobackward.5")
                        .font(.title2)
                }

                Button(action: { viewModel.engine.togglePlayback() }) {
                    Image(systemName: viewModel.engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                }

                Button(action: { viewModel.engine.stepForward(seconds: 5) }) {
                    Image(systemName: "goforward.5")
                        .font(.title2)
                }
            }
            .foregroundColor(.white)
        }
    }
}

/// iOS 工具栏
struct iOSToolbar: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var showingPanel: iOSPanelType?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                iOSToolButton(icon: "scissors", label: "分割") {
                    viewModel.splitSelectedClip()
                }

                iOSToolButton(icon: "trash", label: "删除") {
                    viewModel.deleteSelectedClip()
                }

                iOSToolButton(icon: "speedometer", label: "速度") {
                    showingPanel = .speed
                }

                iOSToolButton(icon: "camera.filters", label: "滤镜") {
                    showingPanel = .filter
                }

                iOSToolButton(icon: "textformat", label: "文字") {
                    showingPanel = .text
                }

                iOSToolButton(icon: "waveform", label: "音频") {
                    showingPanel = .audio
                }

                iOSToolButton(icon: "face.smiling", label: "贴纸") {
                    showingPanel = .stickers
                }

                iOSToolButton(icon: "sparkles", label: "特效") {
                    showingPanel = .effects
                }

                iOSToolButton(icon: "rectangle.on.rectangle", label: "转场") {
                    showingPanel = .transition
                }

                iOSToolButton(icon: "brain", label: "AI") {
                    showingPanel = .ai
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .sheet(item: $showingPanel) { panel in
            iOSPanelSheet(panelType: panel)
                .environmentObject(viewModel)
        }
    }
}

enum iOSPanelType: String, Identifiable {
    case speed, filter, text, audio, stickers, effects, transition, ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speed: return "速度"
        case .filter: return "滤镜"
        case .text: return "文字"
        case .audio: return "音频"
        case .stickers: return "贴纸"
        case .effects: return "特效"
        case .transition: return "转场"
        case .ai: return "AI 功能"
        }
    }
}

/// iOS 工具按钮
struct iOSToolButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(.primary)
        }
    }
}

/// iOS 时间线视图
struct iOSTimelineView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var pixelsPerSecond: CGFloat = 30

    var body: some View {
        VStack(spacing: 0) {
            // 时间线头部
            HStack {
                Text("时间线")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // 缩放控制
                HStack(spacing: 8) {
                    Button(action: { pixelsPerSecond = max(15, pixelsPerSecond - 5) }) {
                        Image(systemName: "minus")
                    }

                    Button(action: { pixelsPerSecond = min(100, pixelsPerSecond + 5) }) {
                        Image(systemName: "plus")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // 时间线内容
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 4) {
                    // 时间标尺
                    iOSTimeRuler(
                        duration: viewModel.engine.project.duration,
                        pixelsPerSecond: pixelsPerSecond
                    )
                    .frame(height: 20)

                    // 轨道
                    ForEach(viewModel.engine.project.tracks) { track in
                        iOSTrackView(
                            track: track,
                            pixelsPerSecond: pixelsPerSecond,
                            selectedClipId: viewModel.engine.selectedClipId
                        ) { clipId in
                            viewModel.engine.selectedClipId = clipId
                        }
                        .frame(height: 50)
                    }
                }
                .frame(minWidth: timelineWidth)
            }
            .background(Color(UIColor.systemBackground))
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    private var timelineWidth: CGFloat {
        let duration = CMTimeGetSeconds(viewModel.engine.project.duration)
        return max(CGFloat(duration) * pixelsPerSecond + 100, UIScreen.main.bounds.width)
    }
}

/// iOS 时间标尺
struct iOSTimeRuler: View {
    let duration: CMTime
    let pixelsPerSecond: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                ForEach(0..<tickCount, id: \.self) { index in
                    let seconds = Double(index)
                    let x = CGFloat(seconds) * pixelsPerSecond

                    if x < geometry.size.width {
                        VStack(spacing: 0) {
                            if index % 5 == 0 {
                                Text(formatTime(seconds))
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }

                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 1, height: index % 5 == 0 ? 8 : 4)
                        }
                        .offset(x: x)
                    }
                }
            }
        }
    }

    private var tickCount: Int {
        Int(CMTimeGetSeconds(duration)) + 20
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}

/// iOS 轨道视图
struct iOSTrackView: View {
    let track: Track
    let pixelsPerSecond: CGFloat
    let selectedClipId: UUID?
    let onClipSelect: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            // 背景
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(UIColor.tertiarySystemBackground))

            // 片段
            ForEach(track.clips) { clip in
                iOSClipView(
                    clip: clip,
                    pixelsPerSecond: pixelsPerSecond,
                    isSelected: selectedClipId == clip.id
                )
                .offset(x: CGFloat(CMTimeGetSeconds(clip.startTime)) * pixelsPerSecond + 4)
                .onTapGesture {
                    onClipSelect(clip.id)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

/// iOS 片段视图
struct iOSClipView: View {
    let clip: Clip
    let pixelsPerSecond: CGFloat
    let isSelected: Bool

    var body: some View {
        let width = CGFloat(CMTimeGetSeconds(clip.duration)) * pixelsPerSecond

        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(clipColor)

            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)

            HStack {
                Text(clip.name)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                Spacer()
            }
        }
        .frame(width: max(width, 30), height: 42)
    }

    private var clipColor: Color {
        switch clip.type {
        case .video: return Color.blue
        case .audio: return Color.green
        case .image: return Color.purple
        }
    }
}

// MARK: - iOS Panel Sheets

struct iOSPanelSheet: View {
    let panelType: iOSPanelType
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    switch panelType {
                    case .speed:
                        iOSSpeedPanel()
                    case .filter:
                        iOSFilterPanel()
                    case .text:
                        iOSTextPanel()
                    case .audio:
                        iOSAudioPanel()
                    case .stickers:
                        iOSStickerPanel()
                    case .effects:
                        iOSEffectsPanel()
                    case .transition:
                        iOSTransitionPanel()
                    case .ai:
                        iOSAIPanel()
                    }
                }
                .padding()
            }
            .navigationTitle(panelType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

struct iOSSpeedPanel: View {
    @State private var speed: Double = 1.0

    let presets: [(String, Double)] = [
        ("0.5x", 0.5), ("0.75x", 0.75), ("1x", 1.0),
        ("1.5x", 1.5), ("2x", 2.0), ("4x", 4.0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("速度预设")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(presets, id: \.1) { preset in
                    Button(action: { speed = preset.1 }) {
                        Text(preset.0)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(speed == preset.1 ? .accentColor : .gray)
                }
            }

            Divider()

            Text("自定义速度: \(String(format: "%.2fx", speed))")
                .font(.subheadline)

            Slider(value: $speed, in: 0.1...4.0)

            Toggle("保持音调", isOn: .constant(true))
        }
    }
}

struct iOSFilterPanel: View {
    @State private var selectedFilter: FilterPreset = .none
    @State private var intensity: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("滤镜预设")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FilterPreset.allCases, id: \.self) { filter in
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedFilter == filter ? Color.accentColor : Color.clear, lineWidth: 2)
                                )

                            Text(filter.rawValue)
                                .font(.caption)
                        }
                        .onTapGesture {
                            selectedFilter = filter
                        }
                    }
                }
            }

            Divider()

            Text("强度")
                .font(.subheadline)

            Slider(value: $intensity, in: 0...1)
        }
    }
}

struct iOSTextPanel: View {
    @State private var text = ""
    @State private var fontSize: Double = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加文字")
                .font(.headline)

            TextField("输入文字...", text: $text)
                .textFieldStyle(.roundedBorder)

            Text("字体大小: \(Int(fontSize))")
                .font(.subheadline)

            Slider(value: $fontSize, in: 12...72)

            Text("样式")
                .font(.subheadline)

            HStack(spacing: 12) {
                ForEach(["普通", "粗体", "描边", "阴影"], id: \.self) { style in
                    Button(style) {}
                        .buttonStyle(.bordered)
                }
            }

            Text("动画")
                .font(.subheadline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(["淡入", "弹入", "打字机", "缩放", "滑入"], id: \.self) { anim in
                        Button(anim) {}
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

struct iOSAudioPanel: View {
    @State private var volume: Double = 1.0
    @State private var fadeIn: Double = 0
    @State private var fadeOut: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("音量")
                .font(.headline)

            HStack {
                Image(systemName: "speaker.fill")
                Slider(value: $volume, in: 0...2)
                Text("\(Int(volume * 100))%")
                    .frame(width: 50)
            }

            Divider()

            Text("淡入淡出")
                .font(.headline)

            HStack {
                Text("淡入")
                Slider(value: $fadeIn, in: 0...3)
                Text(String(format: "%.1fs", fadeIn))
                    .frame(width: 40)
            }

            HStack {
                Text("淡出")
                Slider(value: $fadeOut, in: 0...3)
                Text(String(format: "%.1fs", fadeOut))
                    .frame(width: 40)
            }

            Divider()

            Text("快捷操作")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                Button(action: {}) {
                    Label("分离音频", systemImage: "scissors")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: {}) {
                    Label("降噪", systemImage: "waveform.badge.minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: {}) {
                    Label("变声", systemImage: "person.wave.2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: {}) {
                    Label("标准化", systemImage: "dial.medium")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct iOSStickerPanel: View {
    @StateObject private var stickerManager = StickerManager.shared
    @State private var selectedCategory = "表情"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("表情贴纸")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Array(stickerManager.emojiCategories.keys.sorted()), id: \.self) { category in
                        Button(category) {
                            selectedCategory = category
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedCategory == category ? .accentColor : .gray)
                    }
                }
            }

            if let emojis = stickerManager.emojiCategories[selectedCategory] {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(action: {
                            let sticker = stickerManager.createEmojiSticker(emoji: emoji)
                            stickerManager.addSticker(sticker)
                        }) {
                            Text(emoji)
                                .font(.title)
                        }
                    }
                }
            }

            Divider()

            Text("粒子特效")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ParticleEffectType.allCases.prefix(9), id: \.self) { effect in
                    Button(action: {}) {
                        VStack {
                            Image(systemName: effect.icon)
                                .font(.title2)
                            Text(effect.displayName)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

struct iOSEffectsPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            EffectRow(icon: "rectangle.on.rectangle", title: "画中画", description: "将视频放入画中画窗口")

            EffectRow(icon: "person.crop.rectangle", title: "绿幕抠像", description: "移除绿色/蓝色背景")

            EffectRow(icon: "circle.hexagongrid", title: "模糊马赛克", description: "添加模糊或马赛克效果")

            EffectRow(icon: "gauge.with.needle", title: "速度曲线", description: "创建变速效果")

            EffectRow(icon: "rectangle.split.2x2", title: "分屏", description: "多视频同时显示")

            EffectRow(icon: "cube", title: "LUT 调色", description: "应用专业调色预设")

            EffectRow(icon: "video.badge.waveform", title: "防抖", description: "稳定抖动的视频")
        }
    }
}

struct EffectRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 40)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct iOSTransitionPanel: View {
    @State private var selectedTransition: TransitionType = .crossDissolve
    @State private var duration: Double = 0.5

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("转场效果")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(TransitionType.allCases, id: \.self) { transition in
                    Button(action: { selectedTransition = transition }) {
                        VStack {
                            Image(systemName: transition.icon)
                                .font(.title2)
                            Text(transition.displayName)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedTransition == transition ? .accentColor : .gray)
                }
            }

            Divider()

            Text("时长: \(String(format: "%.1f", duration))秒")
                .font(.subheadline)

            Slider(value: $duration, in: 0.1...2.0)
        }
    }
}

struct iOSAIPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AIFeatureRow(icon: "captions.bubble", title: "自动字幕", description: "语音识别生成字幕")

            AIFeatureRow(icon: "person.crop.rectangle", title: "智能抠图", description: "自动分离人物背景")

            AIFeatureRow(icon: "film.stack", title: "场景检测", description: "自动标记场景切换")

            AIFeatureRow(icon: "face.smiling", title: "人脸检测", description: "检测追踪人脸")

            AIFeatureRow(icon: "wand.and.stars", title: "智能剪辑", description: "AI 推荐剪辑点")

            AIFeatureRow(icon: "music.note.list", title: "智能配乐", description: "推荐匹配的音乐")
        }
    }
}

struct AIFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 40)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    iOSEditorView()
        .environmentObject(EditorViewModel())
}
