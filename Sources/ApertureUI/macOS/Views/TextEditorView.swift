import SwiftUI
import AVFoundation

/// 文字编辑面板
struct TextEditorView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var selectedTextId: UUID?
    @State private var showingAddText = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("文字")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddText = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 文字列表
            if viewModel.engine.project.textOverlays.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "textformat")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("点击 + 添加文字")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(selection: $selectedTextId) {
                    ForEach(viewModel.engine.project.textOverlays) { overlay in
                        TextOverlayRow(overlay: overlay)
                            .tag(overlay.id)
                    }
                    .onDelete(perform: deleteTexts)
                }
                .listStyle(.plain)
            }

            Divider()

            // 编辑面板
            if let textId = selectedTextId,
               let overlay = viewModel.engine.project.textOverlays.first(where: { $0.id == textId }) {
                TextStyleEditor(overlay: overlay) { updated in
                    viewModel.engine.project.updateTextOverlay(updated)
                }
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingAddText) {
            AddTextSheet { newOverlay in
                viewModel.engine.project.addTextOverlay(newOverlay)
                selectedTextId = newOverlay.id
            }
        }
    }

    private func deleteTexts(at offsets: IndexSet) {
        for index in offsets {
            let overlay = viewModel.engine.project.textOverlays[index]
            viewModel.engine.project.removeTextOverlay(id: overlay.id)
        }
    }
}

/// 文字覆盖层行
struct TextOverlayRow: View {
    let overlay: TextOverlay

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(overlay.text)
                    .lineLimit(1)

                Text(formatTimeRange(overlay.timeRange))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: overlay.animation.icon)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatTimeRange(_ range: CMTimeRange) -> String {
        let start = CMTimeGetSeconds(range.start)
        let end = CMTimeGetSeconds(range.end)
        return String(format: "%.1fs - %.1fs", start, end)
    }
}

/// 添加文字弹窗
struct AddTextSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var text = "文字"
    @State private var duration: Double = 3.0
    let onAdd: (TextOverlay) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("添加文字")
                .font(.headline)

            TextField("输入文字", text: $text)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("持续时间")
                Slider(value: $duration, in: 1...10)
                Text("\(String(format: "%.1f", duration))s")
                    .frame(width: 40)
            }

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("添加") {
                    let overlay = TextOverlay(
                        text: text,
                        timeRange: CMTimeRange(
                            start: .zero,
                            duration: CMTime(seconds: duration, preferredTimescale: 600)
                        )
                    )
                    onAdd(overlay)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

/// 文字样式编辑器
struct TextStyleEditor: View {
    let overlay: TextOverlay
    let onUpdate: (TextOverlay) -> Void

    @State private var text: String
    @State private var fontSize: CGFloat
    @State private var fontWeight: FontWeight
    @State private var position: TextPosition
    @State private var animation: TextAnimation

    init(overlay: TextOverlay, onUpdate: @escaping (TextOverlay) -> Void) {
        self.overlay = overlay
        self.onUpdate = onUpdate
        _text = State(initialValue: overlay.text)
        _fontSize = State(initialValue: overlay.style.fontSize)
        _fontWeight = State(initialValue: overlay.style.fontWeight)
        _position = State(initialValue: overlay.position)
        _animation = State(initialValue: overlay.animation)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 文字内容
                VStack(alignment: .leading, spacing: 4) {
                    Text("文字内容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("文字", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: text) { _, newValue in
                            updateOverlay()
                        }
                }

                // 字体大小
                VStack(alignment: .leading, spacing: 4) {
                    Text("字体大小")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: $fontSize, in: 12...120)
                            .onChange(of: fontSize) { _, _ in
                                updateOverlay()
                            }
                        Text("\(Int(fontSize))")
                            .frame(width: 30)
                    }
                }

                // 字体粗细
                VStack(alignment: .leading, spacing: 4) {
                    Text("字体粗细")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $fontWeight) {
                        ForEach(FontWeight.allCases, id: \.self) { weight in
                            Text(weight.rawValue).tag(weight)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: fontWeight) { _, _ in
                        updateOverlay()
                    }
                }

                // 位置
                VStack(alignment: .leading, spacing: 4) {
                    Text("位置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    PositionPicker(position: $position)
                        .onChange(of: position) { _, _ in
                            updateOverlay()
                        }
                }

                // 动画
                VStack(alignment: .leading, spacing: 4) {
                    Text("动画")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $animation) {
                        ForEach(TextAnimation.allCases, id: \.self) { anim in
                            Label(anim.rawValue, systemImage: anim.icon).tag(anim)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: animation) { _, _ in
                        updateOverlay()
                    }
                }
            }
            .padding()
        }
    }

    private func updateOverlay() {
        var updated = overlay
        updated.text = text
        updated.style.fontSize = fontSize
        updated.style.fontWeight = fontWeight
        updated.position = position
        updated.animation = animation
        onUpdate(updated)
    }
}

/// 位置选择器
struct PositionPicker: View {
    @Binding var position: TextPosition

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                positionButton(.topLeft)
                positionButton(.topCenter)
                positionButton(.topRight)
            }
            HStack(spacing: 4) {
                positionButton(.centerLeft)
                positionButton(.center)
                positionButton(.centerRight)
            }
            HStack(spacing: 4) {
                positionButton(.bottomLeft)
                positionButton(.bottomCenter)
                positionButton(.bottomRight)
            }
        }
    }

    private func positionButton(_ pos: TextPosition) -> some View {
        Button(action: { position = pos }) {
            RoundedRectangle(cornerRadius: 2)
                .fill(position == pos ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TextEditorView()
        .environmentObject(EditorViewModel())
        .frame(height: 600)
}
