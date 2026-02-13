import SwiftUI
import AVKit

/// 预览视图
struct PreviewView: View {
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 预览区域
            ZStack {
                Color.black

                if let player = viewModel.engine.player {
                    VideoPlayer(player: player)
                        .disabled(true) // 禁用内置控制
                } else {
                    // 空状态
                    VStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("导入媒体以开始编辑")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 播放控制栏
            PlaybackControls()
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

/// 播放控制
struct PlaybackControls: View {
    @EnvironmentObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 8) {
            // 时间显示
            HStack {
                Text(viewModel.formatTime(viewModel.engine.currentTime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Text(viewModel.formatTime(viewModel.engine.project.duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // 进度条
            ProgressSlider(
                value: Binding(
                    get: { CMTimeGetSeconds(viewModel.engine.currentTime) },
                    set: { seconds in
                        viewModel.engine.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
                    }
                ),
                range: 0...max(CMTimeGetSeconds(viewModel.engine.project.duration), 0.01)
            )
            .padding(.horizontal)

            // 控制按钮
            HStack(spacing: 20) {
                // 跳到开头
                Button(action: { viewModel.engine.seekToBeginning() }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                // 后退
                Button(action: { viewModel.engine.stepBackward() }) {
                    Image(systemName: "gobackward.5")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                // 播放/暂停
                Button(action: { viewModel.engine.togglePlayback() }) {
                    Image(systemName: viewModel.engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(" ", modifiers: [])

                // 前进
                Button(action: { viewModel.engine.stepForward() }) {
                    Image(systemName: "goforward.5")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                // 跳到结尾
                Button(action: { viewModel.engine.seekToEnd() }) {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.primary)
        }
    }
}

/// 自定义进度滑块
struct ProgressSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景轨道
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)

                // 已播放部分
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: progressWidth(in: geometry.size.width), height: 4)

                // 拖动手柄
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 14 : 10, height: isDragging ? 14 : 10)
                    .shadow(radius: 2)
                    .offset(x: progressWidth(in: geometry.size.width) - (isDragging ? 7 : 5))
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newValue = (gesture.location.x / geometry.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.1), value: isDragging)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return max(0, min(totalWidth, CGFloat(percentage) * totalWidth))
    }
}

#Preview {
    PreviewView()
        .environmentObject(EditorViewModel())
        .frame(width: 800, height: 500)
}
