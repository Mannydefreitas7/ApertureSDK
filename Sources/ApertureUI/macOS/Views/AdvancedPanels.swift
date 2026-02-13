import SwiftUI
import AVFoundation

// MARK: - Audio Panel

struct AudioPanelView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    private var audioEngine = AudioEngine.shared

    @State private var volume: Float = 1.0
    @State private var fadeInDuration: Double = 0.5
    @State private var fadeOutDuration: Double = 0.5
    @State private var showEqualizer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "waveform")
                Text("音频设置")
                    .font(.headline)
            }
            .padding(.bottom, 8)

            // 音量控制
            VStack(alignment: .leading, spacing: 8) {
                Text("音量")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .foregroundColor(.secondary)

                    Slider(value: $volume, in: 0...2) { _ in
                        updateVolume()
                    }

                    Text("\(Int(volume * 100))%")
                        .frame(width: 50, alignment: .trailing)
                        .font(.caption)
                }
            }

            Divider()

            // 淡入淡出
            VStack(alignment: .leading, spacing: 8) {
                Text("淡入淡出")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("淡入")
                    Slider(value: $fadeInDuration, in: 0...3)
                    Text(String(format: "%.1fs", fadeInDuration))
                        .frame(width: 40)
                        .font(.caption)
                }

                HStack {
                    Text("淡出")
                    Slider(value: $fadeOutDuration, in: 0...3)
                    Text(String(format: "%.1fs", fadeOutDuration))
                        .frame(width: 40)
                        .font(.caption)
                }

                Button("应用淡入淡出") {
                    applyFades()
                }
                .buttonStyle(.bordered)
            }

            Divider()

            // 均衡器
            DisclosureGroup("均衡器", isExpanded: $showEqualizer) {
                EqualizerView()
            }

            Divider()

            // 快捷操作
            VStack(alignment: .leading, spacing: 8) {
                Text("快捷操作")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    QuickActionButton(icon: "scissors", title: "分离音频") {
                        separateAudio()
                    }

                    QuickActionButton(icon: "speaker.slash", title: "静音片段") {
                        muteClip()
                    }

                    QuickActionButton(icon: "waveform.badge.minus", title: "降噪") {
                        applyNoiseReduction()
                    }

                    QuickActionButton(icon: "dial.medium", title: "标准化") {
                        normalizeAudio()
                    }
                }
            }

            Divider()

            // 变声效果
            VStack(alignment: .leading, spacing: 8) {
                Text("变声效果")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(VoiceChangerPreset.allCases, id: \.self) { preset in
                            VoicePresetButton(preset: preset) {
                                applyVoiceChange(preset)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    private func updateVolume() {
        // Update clip volume
    }

    private func applyFades() {
        // Apply fade in/out
    }

    private func separateAudio() {
        // Separate audio from video
    }

    private func muteClip() {
        volume = 0
        updateVolume()
    }

    private func applyNoiseReduction() {
        // Apply noise reduction
    }

    private func normalizeAudio() {
        // Normalize audio levels
    }

    private func applyVoiceChange(_ preset: VoiceChangerPreset) {
        // Apply voice change effect
    }
}

struct EqualizerView: View {
    @State private var bands: [Float] = Array(repeating: 0, count: 10)
    private let frequencies = ["32", "64", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    VStack(spacing: 4) {
                        Slider(value: $bands[index], in: -12...12)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 20, height: 80)

                        Text(frequencies[index])
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack {
                Button("重置") {
                    bands = Array(repeating: 0, count: 10)
                }
                .buttonStyle(.bordered)

                Spacer()

                Menu("预设") {
                    Button("低音增强") { applyPreset(.bass) }
                    Button("高音增强") { applyPreset(.treble) }
                    Button("人声增强") { applyPreset(.vocal) }
                    Button("现场效果") { applyPreset(.live) }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func applyPreset(_ preset: EQPreset) {
        switch preset {
        case .bass:
            bands = [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]
        case .treble:
            bands = [0, 0, 0, 0, 0, 2, 3, 4, 5, 6]
        case .vocal:
            bands = [-2, -1, 0, 2, 4, 4, 2, 0, -1, -2]
        case .live:
            bands = [4, 2, 0, -1, -2, -1, 0, 2, 3, 4]
        }
    }

    enum EQPreset {
        case bass, treble, vocal, live
    }
}

struct VoicePresetButton: View {
    let preset: VoiceChangerPreset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: preset.icon)
                    .font(.title3)
                Text(preset.displayName)
                    .font(.caption)
            }
            .frame(width: 60, height: 50)
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - Keyframe Panel

struct KeyframePanelView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var selectedProperty: AnimatableProperty = .position
    @State private var showCurveEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.below.square.and.square.filled")
                Text("关键帧动画")
                    .font(.headline)
            }
            .padding(.bottom, 8)

            // 属性选择
            VStack(alignment: .leading, spacing: 8) {
                Text("动画属性")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("属性", selection: $selectedProperty) {
                    ForEach(AnimatableProperty.allCases, id: \.self) { prop in
                        Text(prop.displayName).tag(prop)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            // 关键帧列表
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("关键帧")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: addKeyframe) {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }

                // 关键帧列表区域
                ScrollView {
                    VStack(spacing: 4) {
                        KeyframeRow(time: 0.0, value: "0, 0")
                        KeyframeRow(time: 1.5, value: "100, 50")
                        KeyframeRow(time: 3.0, value: "200, 100")
                    }
                }
                .frame(maxHeight: 120)
            }

            Divider()

            // 缓动函数
            VStack(alignment: .leading, spacing: 8) {
                Text("缓动函数")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach([EasingFunction.linear, .easeIn, .easeOut, .easeInOut, .spring, .bounce], id: \.self) { easing in
                        EasingButton(easing: easing)
                    }
                }
            }

            Divider()

            // 曲线编辑器
            Button(action: { showCurveEditor.toggle() }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("打开曲线编辑器")
                }
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
    }

    private func addKeyframe() {
        // Add keyframe at current time
    }
}

struct KeyframeRow: View {
    let time: Double
    let value: String

    var body: some View {
        HStack {
            Image(systemName: "diamond.fill")
                .font(.caption)
                .foregroundColor(.yellow)

            Text(String(format: "%.2fs", time))
                .font(.caption)
                .frame(width: 50)

            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {}) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
    }
}

struct EasingButton: View {
    let easing: EasingFunction

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 2) {
                EasingCurveShape(easing: easing)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: 30, height: 20)

                Text(easing.displayName)
                    .font(.system(size: 8))
            }
            .frame(height: 45)
        }
        .buttonStyle(.bordered)
    }
}

struct EasingCurveShape: Shape {
    let easing: EasingFunction

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))

        for i in 0...20 {
            let t = CGFloat(i) / 20.0
            let easedT = easing.apply(t)
            let x = rect.minX + t * rect.width
            let y = rect.maxY - easedT * rect.height
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

// MARK: - Effects Panel

struct EffectsPanelView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var selectedEffect: VideoEffectType?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                Text("视频特效")
                    .font(.headline)
            }
            .padding(.bottom, 8)

            // 特效分类
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 画中画
                    EffectSection(title: "画中画", icon: "rectangle.on.rectangle") {
                        PiPControlView()
                    }

                    Divider()

                    // 绿幕/抠像
                    EffectSection(title: "绿幕抠像", icon: "person.crop.rectangle") {
                        ChromaKeyControlView()
                    }

                    Divider()

                    // 模糊/马赛克
                    EffectSection(title: "模糊效果", icon: "circle.hexagongrid") {
                        BlurControlView()
                    }

                    Divider()

                    // 速度曲线
                    EffectSection(title: "速度曲线", icon: "gauge.with.needle") {
                        SpeedCurveControlView()
                    }

                    Divider()

                    // 分屏
                    EffectSection(title: "分屏效果", icon: "rectangle.split.2x2") {
                        SplitScreenControlView()
                    }

                    Divider()

                    // LUT
                    EffectSection(title: "LUT 调色", icon: "cube") {
                        LUTControlView()
                    }
                }
            }
        }
        .padding()
    }
}

struct EffectSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content()
                .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
            }
        }
    }
}

struct PiPControlView: View {
    @State private var pipPosition: PiPPosition = .bottomRight
    @State private var pipScale: CGFloat = 0.3
    @State private var pipCornerRadius: CGFloat = 8
    @State private var hasBorder = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 位置选择
            Text("位置")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                ForEach(PiPPosition.allCases, id: \.self) { pos in
                    Button(action: { pipPosition = pos }) {
                        Image(systemName: pos.icon)
                    }
                    .buttonStyle(.bordered)
                    .tint(pipPosition == pos ? .accentColor : .gray)
                }
            }

            // 缩放
            HStack {
                Text("缩放")
                Slider(value: $pipScale, in: 0.1...0.5)
                Text("\(Int(pipScale * 100))%")
                    .frame(width: 40)
                    .font(.caption)
            }

            // 圆角
            HStack {
                Text("圆角")
                Slider(value: $pipCornerRadius, in: 0...30)
                Text("\(Int(pipCornerRadius))")
                    .frame(width: 30)
                    .font(.caption)
            }

            Toggle("显示边框", isOn: $hasBorder)
        }
    }
}

struct ChromaKeyControlView: View {
    @State private var keyColor: Color = .green
    @State private var threshold: CGFloat = 0.4
    @State private var smoothness: CGFloat = 0.1
    @State private var spillSuppression: CGFloat = 0.5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("抠除颜色")
                Spacer()
                ColorPicker("", selection: $keyColor)
                    .labelsHidden()
            }

            HStack {
                Text("阈值")
                Slider(value: $threshold, in: 0...1)
                Text(String(format: "%.2f", threshold))
                    .frame(width: 40)
                    .font(.caption)
            }

            HStack {
                Text("平滑度")
                Slider(value: $smoothness, in: 0...1)
                Text(String(format: "%.2f", smoothness))
                    .frame(width: 40)
                    .font(.caption)
            }

            HStack {
                Text("溢色抑制")
                Slider(value: $spillSuppression, in: 0...1)
                Text(String(format: "%.2f", spillSuppression))
                    .frame(width: 40)
                    .font(.caption)
            }

            Button("应用绿幕效果") {}
                .buttonStyle(.borderedProminent)
        }
    }
}

struct BlurControlView: View {
    @State private var blurType: BlurType = .gaussian
    @State private var blurRadius: CGFloat = 10
    @State private var useTracking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("类型", selection: $blurType) {
                Text("高斯模糊").tag(BlurType.gaussian)
                Text("马赛克").tag(BlurType.mosaic)
                Text("运动模糊").tag(BlurType.motion)
            }

            HStack {
                Text("强度")
                Slider(value: $blurRadius, in: 1...50)
                Text("\(Int(blurRadius))")
                    .frame(width: 30)
                    .font(.caption)
            }

            Toggle("人脸追踪", isOn: $useTracking)

            Button("添加模糊区域") {}
                .buttonStyle(.bordered)
        }
    }
}

struct SpeedCurveControlView: View {
    @State private var speedPreset: SpeedPreset = .normal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("速度预设")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(SpeedPreset.allCases, id: \.self) { preset in
                    Button(action: { speedPreset = preset }) {
                        VStack {
                            Image(systemName: preset.icon)
                            Text(preset.displayName)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(speedPreset == preset ? .accentColor : .gray)
                }
            }

            Button("打开速度曲线编辑器") {}
                .buttonStyle(.bordered)
        }
    }
}

struct SplitScreenControlView: View {
    @State private var splitLayout: SplitLayout = .twoHorizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分屏布局")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(SplitLayout.allCases, id: \.self) { layout in
                    Button(action: { splitLayout = layout }) {
                        Image(systemName: layout.icon)
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                    .tint(splitLayout == layout ? .accentColor : .gray)
                }
            }
        }
    }
}

struct LUTControlView: View {
    @State private var lutIntensity: CGFloat = 1.0

    let lutPresets = ["Cinematic", "Vintage", "Warm", "Cool", "B&W", "Teal & Orange"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LUT 预设")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(lutPresets, id: \.self) { lut in
                        Button(action: {}) {
                            VStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray)
                                    .frame(width: 50, height: 35)

                                Text(lut)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Text("强度")
                Slider(value: $lutIntensity, in: 0...1)
                Text("\(Int(lutIntensity * 100))%")
                    .frame(width: 40)
                    .font(.caption)
            }

            Button("导入 LUT 文件") {}
                .buttonStyle(.bordered)
        }
    }
}

// MARK: - Stickers Panel

struct StickersPanelView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @StateObject private var stickerManager = StickerManager.shared
    @State private var selectedCategory = "表情"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "face.smiling")
                Text("贴纸与特效")
                    .font(.headline)
            }
            .padding(.bottom, 8)

            // 分类选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(stickerManager.emojiCategories.keys.sorted()), id: \.self) { category in
                        Button(action: { selectedCategory = category }) {
                            Text(category)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedCategory == category ? .accentColor : .gray)
                    }
                }
            }

            // 贴纸网格
            if let emojis = stickerManager.emojiCategories[selectedCategory] {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(action: { addEmojiSticker(emoji) }) {
                            Text(emoji)
                                .font(.title)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // 粒子特效
            VStack(alignment: .leading, spacing: 8) {
                Text("粒子特效")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(ParticleEffectType.allCases.prefix(12), id: \.self) { effect in
                        Button(action: { addParticleEffect(effect) }) {
                            VStack(spacing: 4) {
                                Image(systemName: effect.icon)
                                    .font(.title3)
                                Text(effect.displayName)
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Divider()

            // 边框模板
            VStack(alignment: .leading, spacing: 8) {
                Text("边框模板")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(stickerManager.builtInFrames) { frame in
                            Button(action: { stickerManager.selectedFrame = frame }) {
                                VStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.accentColor, lineWidth: stickerManager.selectedFrame?.id == frame.id ? 2 : 0)
                                        .frame(width: 50, height: 35)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 2)
                                                .stroke(Color.gray, lineWidth: 1)
                                                .padding(4)
                                        )

                                    Text(frame.name)
                                        .font(.caption2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    private func addEmojiSticker(_ emoji: String) {
        let sticker = stickerManager.createEmojiSticker(emoji: emoji)
        stickerManager.addSticker(sticker)
    }

    private func addParticleEffect(_ type: ParticleEffectType) {
        let effect = ParticleEffect(type: type)
        stickerManager.addParticleEffect(effect)
    }
}

// MARK: - AI Panel

struct AIPanelView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain")
                Text("AI 功能")
                    .font(.headline)
            }
            .padding(.bottom, 8)

            // AI 功能列表
            ScrollView {
                VStack(spacing: 12) {
                    AIFeatureCard(
                        icon: "captions.bubble",
                        title: "自动字幕",
                        description: "使用语音识别自动生成字幕"
                    ) {
                        generateSubtitles()
                    }

                    AIFeatureCard(
                        icon: "person.crop.rectangle",
                        title: "智能抠图",
                        description: "自动识别并分离人物/主体"
                    ) {
                        extractSubject()
                    }

                    AIFeatureCard(
                        icon: "film.stack",
                        title: "场景检测",
                        description: "自动检测并标记场景切换点"
                    ) {
                        detectScenes()
                    }

                    AIFeatureCard(
                        icon: "face.smiling",
                        title: "人脸检测",
                        description: "检测并追踪视频中的人脸"
                    ) {
                        detectFaces()
                    }

                    AIFeatureCard(
                        icon: "wand.and.stars",
                        title: "智能剪辑建议",
                        description: "分析素材并提供剪辑建议"
                    ) {
                        getEditSuggestions()
                    }

                    AIFeatureCard(
                        icon: "music.note.list",
                        title: "智能配乐",
                        description: "根据视频内容推荐背景音乐"
                    ) {
                        suggestMusic()
                    }
                }
            }

            // 处理状态
            if isProcessing {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
    }

    private func generateSubtitles() {
        isProcessing = true
        statusMessage = "正在识别语音..."
        // Simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isProcessing = false
        }
    }

    private func extractSubject() {
        isProcessing = true
        statusMessage = "正在分析视频..."
    }

    private func detectScenes() {
        isProcessing = true
        statusMessage = "正在检测场景..."
    }

    private func detectFaces() {
        isProcessing = true
        statusMessage = "正在检测人脸..."
    }

    private func getEditSuggestions() {
        isProcessing = true
        statusMessage = "正在分析素材..."
    }

    private func suggestMusic() {
        isProcessing = true
        statusMessage = "正在匹配音乐..."
    }
}

struct AIFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 40)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
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
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helper Views

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }
}



// MARK: - Voice Changer Presets

enum VoiceChangerPreset: String, CaseIterable, Hashable {
    case normal
    case chipmunk
    case robot
    case deep
    case echo

    var displayName: String {
        switch self {
        case .normal: return "原声"
        case .chipmunk: return "花栗鼠"
        case .robot: return "机器人"
        case .deep: return "低沉"
        case .echo: return "回声"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "waveform"
        case .chipmunk: return "hare"
        case .robot: return "antenna.radiowaves.left.and.right"
        case .deep: return "tortoise"
        case .echo: return "dot.radiowaves.left.and.right"
        }
    }
}


// MARK: - Enums for UI

enum BlurType: String, CaseIterable {
    case gaussian
    case mosaic
    case motion
}

enum SpeedPreset: String, CaseIterable {
    case slow50 = "0.5x"
    case slow75 = "0.75x"
    case normal = "1x"
    case fast150 = "1.5x"
    case fast200 = "2x"
    case fast400 = "4x"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .slow50, .slow75: return "tortoise"
        case .normal: return "figure.walk"
        case .fast150, .fast200: return "hare"
        case .fast400: return "bolt"
        }
    }
}

enum SplitLayout: String, CaseIterable {
    case twoHorizontal
    case twoVertical
    case threeTop
    case threeLeft
    case fourGrid
    case sixGrid

    var icon: String {
        switch self {
        case .twoHorizontal: return "rectangle.split.2x1"
        case .twoVertical: return "rectangle.split.1x2"
        case .threeTop: return "rectangle.split.3x1"
        case .threeLeft: return "rectangle.split.1x2.fill"
        case .fourGrid: return "rectangle.split.2x2"
        case .sixGrid: return "rectangle.split.3x3"
        }
    }
}

/// 视频特效类型，对应 VideoEffects.swift 中的效果选项
enum VideoEffectType: String, CaseIterable, Identifiable {
    case pictureInPicture
    case chromaKey
    case blur
    case mosaic
    case speedCurve
    case splitScreen
    case lut
    case stabilization
    case lensCorrection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pictureInPicture: return "画中画"
        case .chromaKey: return "绿幕/抠像"
        case .blur: return "模糊"
        case .mosaic: return "马赛克"
        case .speedCurve: return "速度曲线"
        case .splitScreen: return "分屏"
        case .lut: return "LUT 调色"
        case .stabilization: return "防抖"
        case .lensCorrection: return "镜头校正"
        }
    }
    
    var icon: String {
        switch self {
        case .pictureInPicture: return "rectangle.on.rectangle"
        case .chromaKey: return "person.crop.rectangle"
        case .blur: return "drop"
        case .mosaic: return "circle.hexagongrid"
        case .speedCurve: return "gauge.with.needle"
        case .splitScreen: return "rectangle.split.2x2"
        case .lut: return "cube"
        case .stabilization: return "video"
        case .lensCorrection: return "camera.metering.center.weighted"
        }
    }
}

extension ParticleEffectType {
    var icon: String {
        switch self {
        case .confetti: return "party.popper"
        case .snow: return "snowflake"
        case .rain: return "cloud.rain"
        case .fire: return "flame"
        case .sparkles: return "sparkles"
        case .hearts: return "heart.fill"
        case .stars: return "star.fill"
        case .bubbles: return "bubble.left.and.bubble.right"
        case .smoke: return "smoke"
        case .leaves: return "leaf"
        case .petals: return "camera.macro"
        case .fireworks: return "sparkle"
        case .dust: return "aqi.medium"
        case .magic: return "wand.and.stars"
        case .coins: return "bitcoinsign.circle"
        case .emojis: return "face.smiling"
        }
    }
}

