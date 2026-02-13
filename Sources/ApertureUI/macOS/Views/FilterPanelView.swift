import SwiftUI

/// 滤镜面板视图
struct FilterPanelView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var selectedFilter: FilterType = .none
    @State private var filterIntensity: Float = 1.0
    @State private var parameters = FilterParameters()

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("滤镜")
                    .font(.headline)
                Spacer()
                Button("重置") {
                    resetFilter()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    // 预设滤镜
                    FilterPresetsGrid(
                        selectedFilter: $selectedFilter,
                        onSelect: { filter in
                            applyFilter(type: filter)
                        }
                    )

                    Divider()
                        .padding(.horizontal)

                    // 滤镜强度
                    if selectedFilter != .none {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("强度")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack {
                                Slider(value: $filterIntensity, in: 0...1)
                                Text("\(Int(filterIntensity * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 40)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // 调整参数
                    ColorAdjustmentsView(parameters: $parameters, onChange: updateFilter)
                }
                .padding(.vertical)
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func applyFilter(type: FilterType) {
        selectedFilter = type
        updateFilter()
    }

    private func updateFilter() {
        let filter = VideoFilter(
            type: selectedFilter,
            intensity: filterIntensity,
            parameters: parameters
        )

        // 应用到选中的片段或全局
        if let clipId = viewModel.engine.selectedClipId,
           var track = viewModel.engine.project.track(containingClip: clipId),
           let index = track.clips.firstIndex(where: { $0.id == clipId }) {
            track.clips[index].filter = filter
            viewModel.engine.project.updateTrack(track)
        } else {
            viewModel.engine.project.setGlobalFilter(filter)
        }
    }

    private func resetFilter() {
        selectedFilter = .none
        filterIntensity = 1.0
        parameters = FilterParameters()
        updateFilter()
    }
}

/// 滤镜预设网格
struct FilterPresetsGrid: View {
    @Binding var selectedFilter: FilterType
    let onSelect: (FilterType) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 90), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(FilterType.allCases, id: \.self) { filter in
                FilterPresetItem(
                    filter: filter,
                    isSelected: selectedFilter == filter
                ) {
                    selectedFilter = filter
                    onSelect(filter)
                }
            }
        }
        .padding(.horizontal)
    }
}

/// 滤镜预设项
struct FilterPresetItem: View {
    let filter: FilterType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // 预览图
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(previewColor)
                        .frame(height: 50)

                    Image(systemName: filter.icon)
                        .foregroundColor(.white)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )

                // 名称
                Text(filter.displayName)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var previewColor: Color {
        switch filter {
        case .none: return .gray
        case .vivid: return .orange
        case .dramatic: return .purple
        case .mono: return .gray
        case .noir: return .black
        case .silvertone: return .gray.opacity(0.7)
        case .vintage: return .brown
        case .warm: return .orange.opacity(0.8)
        case .cool: return .blue.opacity(0.8)
        case .fade: return .gray.opacity(0.5)
        case .chrome: return .yellow
        case .process: return .green
        case .transfer: return .indigo
        case .instant: return .pink
        case .colorAdjust: return .blue
        }
    }
}

/// 色彩调整视图
struct ColorAdjustmentsView: View {
    @Binding var parameters: FilterParameters
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("调整")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Group {
                AdjustmentSlider(
                    label: "亮度",
                    value: $parameters.brightness,
                    range: -1...1,
                    onChange: onChange
                )

                AdjustmentSlider(
                    label: "对比度",
                    value: $parameters.contrast,
                    range: 0.5...2,
                    defaultValue: 1.0,
                    onChange: onChange
                )

                AdjustmentSlider(
                    label: "饱和度",
                    value: $parameters.saturation,
                    range: 0...2,
                    defaultValue: 1.0,
                    onChange: onChange
                )

                AdjustmentSlider(
                    label: "曝光",
                    value: $parameters.exposure,
                    range: -2...2,
                    onChange: onChange
                )

                AdjustmentSlider(
                    label: "色温",
                    value: Binding(
                        get: { Float((parameters.temperature - 2000) / 8000) },
                        set: { parameters.temperature = $0 * 8000 + 2000 }
                    ),
                    range: 0...1,
                    defaultValue: 0.5625,
                    onChange: onChange
                )

                AdjustmentSlider(
                    label: "高光",
                    value: $parameters.highlights,
                    range: 0...2,
                    defaultValue: 1.0,
                    onChange: onChange
                )

                AdjustmentSlider(
                    label: "阴影",
                    value: $parameters.shadows,
                    range: -1...1,
                    onChange: onChange
                )

                AdjustmentSlider(
                    label: "锐度",
                    value: $parameters.sharpness,
                    range: 0...2,
                    onChange: onChange
                )

                AdjustmentSlider(
                    label: "暗角",
                    value: $parameters.vignette,
                    range: 0...2,
                    onChange: onChange
                )
            }
            .padding(.horizontal)
        }
    }
}

/// 调整滑块
struct AdjustmentSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    var defaultValue: Float = 0
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Slider(value: $value, in: range)
                    .onChange(of: value) { _, _ in
                        onChange()
                    }

                Button(action: {
                    value = defaultValue
                    onChange()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    FilterPanelView()
        .environmentObject(EditorViewModel())
        .frame(height: 600)
}
