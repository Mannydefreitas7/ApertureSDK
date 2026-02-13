import SwiftUI
import AVFoundation

struct AdvancedExportView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @Environment(\.dismiss) var dismiss

    @State private var exportMode: ExportMode = .video
    @State private var selectedPreset: SocialMediaPreset?
    @State private var customSettings = CustomExportSettings()
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportStatus = ""

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("导出")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            HStack(spacing: 0) {
                // 左侧 - 导出模式选择
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(ExportMode.allCases, id: \.self) { mode in
                        ExportModeButton(mode: mode, isSelected: exportMode == mode) {
                            exportMode = mode
                        }
                    }
                    Spacer()
                }
                .frame(width: 180)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // 右侧 - 设置内容
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch exportMode {
                        case .video:
                            VideoExportSettingsView(settings: $customSettings)
                        case .gif:
                            GIFExportSettingsView(settings: $customSettings)
                        case .imageSequence:
                            ImageSequenceSettingsView(settings: $customSettings)
                        case .audioOnly:
                            AudioExportSettingsView(settings: $customSettings)
                        case .socialMedia:
                            SocialMediaExportView(selectedPreset: $selectedPreset)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            // 底部 - 导出按钮和进度
            VStack(spacing: 12) {
                if isExporting {
                    VStack(spacing: 8) {
                        ProgressView(value: exportProgress)
                        Text(exportStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    // 预估文件大小
                    Text("预估大小: \(estimatedFileSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("取消") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)

                    Button("导出") {
                        startExport()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExporting)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 700, height: 550)
    }

    private var estimatedFileSize: String {
        // Estimate based on settings
        let duration = CMTimeGetSeconds(viewModel.engine.project.duration)
        let bitrate: Double

        switch customSettings.quality {
        case .low: bitrate = 2_000_000
        case .medium: bitrate = 8_000_000
        case .high: bitrate = 16_000_000
        case .ultra: bitrate = 50_000_000
        }

        let bytes = (bitrate * duration) / 8
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func startExport() {
        isExporting = true
        exportProgress = 0
        exportStatus = "准备导出..."

        // Simulate export progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            exportProgress += 0.02
            if exportProgress >= 1.0 {
                timer.invalidate()
                isExporting = false
                dismiss()
            }
        }
    }
}

enum ExportMode: String, CaseIterable {
    case video = "视频"
    case gif = "GIF"
    case imageSequence = "图片序列"
    case audioOnly = "仅音频"
    case socialMedia = "社交媒体"

    var icon: String {
        switch self {
        case .video: return "film"
        case .gif: return "photo.on.rectangle.angled"
        case .imageSequence: return "photo.stack"
        case .audioOnly: return "waveform"
        case .socialMedia: return "square.and.arrow.up"
        }
    }
}

struct ExportModeButton: View {
    let mode: ExportMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .frame(width: 20)
                Text(mode.rawValue)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

struct CustomExportSettings {
    var resolution: ExportResolution = .hd1080
    var frameRate: Double = 30
    var quality: ExportQuality = .high
    var format: VideoFormat = .mp4
    var audioFormat: AudioExportFormat = .m4a
    var gifFps: Int = 15
    var gifWidth: Int = 480
    var imageFormat: ImageSequenceFormat = .png
}

enum ExportResolution: String, CaseIterable {
    case sd480 = "480p"
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4k = "4K"

    var size: CGSize {
        switch self {
        case .sd480: return CGSize(width: 854, height: 480)
        case .hd720: return CGSize(width: 1280, height: 720)
        case .hd1080: return CGSize(width: 1920, height: 1080)
        case .uhd4k: return CGSize(width: 3840, height: 2160)
        }
    }
}

enum ExportQuality: String, CaseIterable {
    case low = "低"
    case medium = "中"
    case high = "高"
    case ultra = "极高"
}

enum VideoFormat: String, CaseIterable {
    case mp4 = "MP4"
    case mov = "MOV"
    case webm = "WebM"
}

enum AudioExportFormat: String, CaseIterable {
    case m4a = "M4A"
    case mp3 = "MP3"
    case wav = "WAV"
    case aiff = "AIFF"
}

enum ImageSequenceFormat: String, CaseIterable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"
}

// MARK: - Video Export Settings

struct VideoExportSettingsView: View {
    @Binding var settings: CustomExportSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("视频设置")
                .font(.headline)

            Group {
                // 分辨率
                VStack(alignment: .leading, spacing: 8) {
                    Text("分辨率")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("", selection: $settings.resolution) {
                        ForEach(ExportResolution.allCases, id: \.self) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 帧率
                VStack(alignment: .leading, spacing: 8) {
                    Text("帧率")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("", selection: $settings.frameRate) {
                        Text("24 fps").tag(24.0)
                        Text("30 fps").tag(30.0)
                        Text("60 fps").tag(60.0)
                    }
                    .pickerStyle(.segmented)
                }

                // 质量
                VStack(alignment: .leading, spacing: 8) {
                    Text("质量")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("", selection: $settings.quality) {
                        ForEach(ExportQuality.allCases, id: \.self) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 格式
                VStack(alignment: .leading, spacing: 8) {
                    Text("格式")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("", selection: $settings.format) {
                        ForEach(VideoFormat.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}

// MARK: - GIF Export Settings

struct GIFExportSettingsView: View {
    @Binding var settings: CustomExportSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GIF 设置")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("帧率: \(settings.gifFps) fps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Slider(value: Binding(
                    get: { Double(settings.gifFps) },
                    set: { settings.gifFps = Int($0) }
                ), in: 5...30, step: 1)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("宽度: \(settings.gifWidth) px")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Slider(value: Binding(
                    get: { Double(settings.gifWidth) },
                    set: { settings.gifWidth = Int($0) }
                ), in: 240...800, step: 40)
            }

            // 预设
            VStack(alignment: .leading, spacing: 8) {
                Text("快速预设")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    GIFPresetButton(title: "小", fps: 10, width: 320) { fps, width in
                        settings.gifFps = fps
                        settings.gifWidth = width
                    }
                    GIFPresetButton(title: "中", fps: 15, width: 480) { fps, width in
                        settings.gifFps = fps
                        settings.gifWidth = width
                    }
                    GIFPresetButton(title: "大", fps: 20, width: 640) { fps, width in
                        settings.gifFps = fps
                        settings.gifWidth = width
                    }
                }
            }
        }
    }
}

struct GIFPresetButton: View {
    let title: String
    let fps: Int
    let width: Int
    let action: (Int, Int) -> Void

    var body: some View {
        Button(action: { action(fps, width) }) {
            VStack {
                Text(title)
                    .font(.subheadline)
                Text("\(fps)fps / \(width)px")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - Image Sequence Settings

struct ImageSequenceSettingsView: View {
    @Binding var settings: CustomExportSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("图片序列设置")
                .font(.headline)

            // 格式
            VStack(alignment: .leading, spacing: 8) {
                Text("图片格式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $settings.imageFormat) {
                    ForEach(ImageSequenceFormat.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 分辨率
            VStack(alignment: .leading, spacing: 8) {
                Text("分辨率")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $settings.resolution) {
                    ForEach(ExportResolution.allCases, id: \.self) { res in
                        Text(res.rawValue).tag(res)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 帧率说明
            VStack(alignment: .leading, spacing: 4) {
                Text("帧率: \(Int(settings.frameRate)) fps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("将导出每秒 \(Int(settings.frameRate)) 张图片")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Audio Export Settings

struct AudioExportSettingsView: View {
    @Binding var settings: CustomExportSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("音频设置")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("格式")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $settings.audioFormat) {
                    ForEach(AudioExportFormat.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
            }

            // 质量
            VStack(alignment: .leading, spacing: 8) {
                Text("质量")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $settings.quality) {
                    ForEach(ExportQuality.allCases, id: \.self) { q in
                        Text(q.rawValue).tag(q)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - Social Media Export

struct SocialMediaExportView: View {
    @Binding var selectedPreset: SocialMediaPreset?

    let presets: [(category: String, presets: [SocialMediaPreset])] = [
        ("短视频平台", [.tiktok, .instagramReels, .youtubeShorts]),
        ("社交媒体", [.instagramFeed, .instagramStory]),
        ("视频平台", [.youtube, .vimeo]),
        ("其他", [.twitter, .facebook, .linkedin])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("社交媒体预设")
                .font(.headline)

            Text("选择平台，自动优化视频参数")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(presets, id: \.category) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(section.presets, id: \.self) { preset in
                            SocialMediaPresetCard(
                                preset: preset,
                                isSelected: selectedPreset == preset
                            ) {
                                selectedPreset = preset
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SocialMediaPresetCard: View {
    let preset: SocialMediaPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: preset.icon)
                        .foregroundColor(preset.brandColor)
                    Text(preset.displayName)
                        .fontWeight(.medium)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }

                Text(preset.specs)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

extension SocialMediaPreset {
    var icon: String {
        switch self {
        case .tiktok: return "play.rectangle"
        case .instagramReels, .instagramFeed, .instagramStory: return "camera"
        case .youtubeShorts, .youtube: return "play.rectangle.fill"
        case .twitter: return "bird"
        case .facebook: return "person.2"
        case .linkedin: return "briefcase"
        case .vimeo: return "v.circle"
        case .snapchat: return "camera.viewfinder"
        case .pinterest: return "pin"
        case .reddit: return "bubble.left.and.bubble.right"
        case .custom: return "slider.horizontal.3"
        }
    }

    var brandColor: Color {
        switch self {
        case .tiktok: return .pink
        case .instagramReels, .instagramFeed, .instagramStory: return .purple
        case .youtubeShorts, .youtube: return .red
        default: return .accentColor
        }
    }

    var specs: String {
        switch self {
        case .tiktok: return "1080x1920 / 60fps / 最长10分钟"
        case .instagramReels: return "1080x1920 / 30fps / 最长90秒"
        case .instagramFeed: return "1080x1080 / 30fps / 最长60秒"
        case .instagramStory: return "1080x1920 / 30fps / 15秒"
        case .youtubeShorts: return "1080x1920 / 60fps / 最长60秒"
        case .youtube: return "3840x2160 / 60fps"
        default: return "1080p / 30fps"
        }
    }
}

#Preview {
    AdvancedExportView()
        .environmentObject(EditorViewModel())
}
