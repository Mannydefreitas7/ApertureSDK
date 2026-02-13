import SwiftUI
import AVKit

/// 主编辑器视图
struct MainEditorView: View {
    @EnvironmentObject var viewModel: EditorViewModel

    /// 侧边栏宽度
    @State private var sidebarWidth: CGFloat = 280

    /// 时间线高度
    @State private var timelineHeight: CGFloat = 250

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            TopToolbar()
                .frame(height: 44)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 主内容区域
            HSplitView {
                // 左侧 - 媒体库
                MediaLibraryView()
                    .frame(minWidth: 200, idealWidth: sidebarWidth, maxWidth: 400)

                // 中间 + 右侧
                VSplitView {
                    // 预览区域
                    HStack(spacing: 0) {
                        // 预览播放器
                        PreviewView()
                            .frame(maxWidth: .infinity)

                        Divider()

                        // 右侧面板（根据模式切换）
                        RightPanel()
                            .frame(width: 280)
                    }

                    // 时间线
                    TimelineView()
                        .frame(minHeight: 150, idealHeight: timelineHeight, maxHeight: 400)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("错误", isPresented: $viewModel.showingError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .fileImporter(
            isPresented: $viewModel.showingImportPanel,
            allowedContentTypes: [.movie, .audio, .image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task {
                    await viewModel.importMedia(urls: urls)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
                viewModel.showingError = true
            }
        }
    }
}

/// 顶部工具栏
struct TopToolbar: View {
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 16) {
            // 左侧 - 项目信息
            HStack(spacing: 8) {
                Image(systemName: "film")
                    .foregroundColor(.secondary)
                Text(viewModel.engine.project.name)
                    .font(.headline)
            }
            .padding(.leading)

            Spacer()

            // 中间 - 编辑工具
            HStack(spacing: 4) {
                ForEach(EditorTool.allCases, id: \.self) { tool in
                    ToolButton(
                        icon: tool.icon,
                        label: tool.rawValue,
                        isSelected: viewModel.currentTool == tool
                    ) {
                        viewModel.currentTool = tool
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            Spacer()

            // 右侧 - 导出按钮
            Button(action: {
                viewModel.showingExportPanel = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.trailing)
        }
    }
}

/// 工具按钮
struct ToolButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.caption2)
            }
            .frame(width: 50, height: 40)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

/// 属性检查面板
struct InspectorPanel: View {
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack {
                Text("属性")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 内容
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let clipId = viewModel.engine.selectedClipId,
                       let track = viewModel.engine.project.track(containingClip: clipId),
                       let clip = track.clips.first(where: { $0.id == clipId }) {
                        ClipInspector(clip: clip)
                    } else {
                        // 项目属性
                        ProjectInspector()
                    }
                }
                .padding()
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

/// 片段检查器
struct ClipInspector: View {
    let clip: Clip

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 片段信息
            Group {
                InspectorRow(label: "名称", value: clip.name)
                InspectorRow(label: "类型", value: clip.type.rawValue)
                InspectorRow(label: "时长", value: formatDuration(clip.duration))
            }

            Divider()

            // 变换
            Group {
                Text("变换")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // TODO: 添加位置、缩放、旋转控制
            }
        }
    }

    func formatDuration(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, secs, ms)
    }
}

/// 项目检查器
struct ProjectInspector: View {
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("项目设置")
                .font(.subheadline)
                .foregroundColor(.secondary)

            InspectorRow(
                label: "分辨率",
                value: viewModel.engine.project.settings.resolution.displayName
            )

            InspectorRow(
                label: "帧率",
                value: "\(Int(viewModel.engine.project.settings.frameRate)) fps"
            )

            InspectorRow(
                label: "总时长",
                value: viewModel.formatTime(viewModel.engine.project.duration)
            )
        }
    }
}

/// 检查器行
struct InspectorRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }
}

/// 右侧面板（根据模式切换）
struct RightPanel: View {
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 面板切换按钮
            HStack(spacing: 0) {
                ForEach(RightPanelMode.allCases, id: \.self) { mode in
                    Button(action: { viewModel.rightPanelMode = mode }) {
                        VStack(spacing: 2) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14))
                            Text(mode.rawValue)
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(viewModel.rightPanelMode == mode ? Color.accentColor.opacity(0.15) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(viewModel.rightPanelMode == mode ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 面板内容
            ScrollView {
                switch viewModel.rightPanelMode {
                case .inspector:
                    InspectorPanel()
                case .filter:
                    FilterPanelView()
                case .text:
                    TextEditorView()
                case .transition:
                    TransitionPanelView()
                case .audio:
                    AudioPanelView()
                case .keyframe:
                    KeyframePanelView()
                case .effects:
                    EffectsPanelView()
                case .stickers:
                    StickersPanelView()
                case .ai:
                    AIPanelView()
                }
            }
        }
    }
}

#Preview {
    MainEditorView()
        .environmentObject(EditorViewModel())
        .frame(width: 1200, height: 800)
}
