import SwiftUI
import AVFoundation

/// 转场面板视图
struct TransitionPanelView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var selectedTransitionType: TransitionType = .crossDissolve
    @State private var transitionDuration: Double = 0.5

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("转场")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // 转场类型网格
                    TransitionTypesGrid(
                        selectedType: $selectedTransitionType,
                        onSelect: { type in
                            selectedTransitionType = type
                        }
                    )

                    Divider()
                        .padding(.horizontal)

                    // 转场时长
                    VStack(alignment: .leading, spacing: 8) {
                        Text("转场时长")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Slider(value: $transitionDuration, in: 0.1...2.0)
                            Text("\(String(format: "%.1f", transitionDuration))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 40)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // 应用按钮
                    VStack(spacing: 12) {
                        Text("选择两个相邻的片段，然后点击应用添加转场效果")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: applyTransition) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("应用转场")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canApplyTransition)
                    }
                    .padding()

                    // 已添加的转场列表
                    if !viewModel.engine.project.transitions.isEmpty {
                        Divider()
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("已添加的转场")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            ForEach(viewModel.engine.project.transitions) { transition in
                                TransitionRow(transition: transition) {
                                    viewModel.engine.project.removeTransition(id: transition.id)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var canApplyTransition: Bool {
        // 检查是否有选中的片段且有相邻片段
        guard let clipId = viewModel.engine.selectedClipId,
              let track = viewModel.engine.project.track(containingClip: clipId),
              let clipIndex = track.clips.firstIndex(where: { $0.id == clipId }),
              clipIndex + 1 < track.clips.count else {
            return false
        }
        return true
    }

    private func applyTransition() {
        guard let clipId = viewModel.engine.selectedClipId,
              let track = viewModel.engine.project.track(containingClip: clipId),
              let clipIndex = track.clips.firstIndex(where: { $0.id == clipId }),
              clipIndex + 1 < track.clips.count else {
            return
        }

        let fromClip = track.clips[clipIndex]
        let toClip = track.clips[clipIndex + 1]

        let transition = Transition(
            type: selectedTransitionType,
            duration: CMTime(seconds: transitionDuration, preferredTimescale: 600),
            fromClipId: fromClip.id,
            toClipId: toClip.id
        )

        viewModel.engine.project.addTransition(transition)
    }
}

/// 转场类型网格
struct TransitionTypesGrid: View {
    @Binding var selectedType: TransitionType
    let onSelect: (TransitionType) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 90), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(TransitionType.allCases, id: \.self) { type in
                TransitionTypeItem(
                    type: type,
                    isSelected: selectedType == type
                ) {
                    selectedType = type
                    onSelect(type)
                }
            }
        }
        .padding(.horizontal)
    }
}

/// 转场类型项
struct TransitionTypeItem: View {
    let type: TransitionType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 50)

                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .accentColor : .primary)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )

                // 名称
                Text(type.displayName)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// 转场行
struct TransitionRow: View {
    let transition: Transition
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: transition.type.icon)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(transition.type.displayName)
                    .font(.callout)

                Text("\(String(format: "%.1f", CMTimeGetSeconds(transition.duration)))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
        .cornerRadius(6)
        .padding(.horizontal)
    }
}

#Preview {
    TransitionPanelView()
        .environmentObject(EditorViewModel())
        .frame(height: 500)
}
