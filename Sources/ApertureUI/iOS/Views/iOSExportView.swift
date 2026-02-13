import SwiftUI

/// iOS 导出视图
struct iOSExportView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var selectedPreset: VideoExporter.ExportPreset = .highest
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportedURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 预览缩略图
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)

                    Image(systemName: "film")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    // 时长标签
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(viewModel.formatTime(viewModel.engine.project.duration))
                                .font(.caption)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                                .padding()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                // 导出设置
                VStack(alignment: .leading, spacing: 16) {
                    Text("导出设置")
                        .font(.headline)
                        .padding(.horizontal)

                    // 质量选择
                    VStack(spacing: 0) {
                        ForEach(exportPresets, id: \.preset) { option in
                            Button(action: { selectedPreset = option.preset }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.title)
                                            .font(.body)
                                            .foregroundColor(.primary)

                                        Text(option.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if selectedPreset == option.preset {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                            }
                            .buttonStyle(.plain)

                            if option.preset != exportPresets.last?.preset {
                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // 预估文件大小
                    HStack {
                        Text("预估文件大小")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(estimatedFileSize)
                            .foregroundColor(.primary)
                    }
                    .font(.callout)
                    .padding(.horizontal)
                }

                // 导出按钮
                Button(action: startExport) {
                    HStack {
                        if viewModel.engine.exporter.isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }

                        Text(viewModel.engine.exporter.isExporting ? "导出中..." : "导出视频")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(viewModel.engine.exporter.isExporting || viewModel.engine.project.duration == .zero)
                .padding(.horizontal)

                // 导出进度
                if viewModel.engine.exporter.isExporting {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(viewModel.engine.exporter.progress))
                            .progressViewStyle(.linear)

                        Text("\(Int(viewModel.engine.exporter.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedURL {
                ShareSheet(items: [url])
            }
        }
    }

    private var exportPresets: [(preset: VideoExporter.ExportPreset, title: String, subtitle: String)] {
        [
            (.highest, "最高质量", "原始分辨率，文件较大"),
            (.h264_1080p, "1080p HD", "H.264 编码，兼容性好"),
            (.hevc_1080p, "1080p HEVC", "更小文件，现代设备支持"),
            (.high, "720p", "适合网络分享"),
            (.medium, "540p", "小文件，快速分享")
        ]
    }

    private var estimatedFileSize: String {
        let size = VideoExporter.estimateFileSize(
            duration: viewModel.engine.project.duration,
            preset: selectedPreset
        )
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func startExport() {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(viewModel.engine.project.name)
            .appendingPathExtension("mp4")

        Task {
            do {
                try await viewModel.exportVideo(to: outputURL, preset: selectedPreset)
                exportedURL = outputURL
                showingShareSheet = true
            } catch {
                // 错误处理已在 ViewModel 中
            }
        }
    }
}

/// 分享表单
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    iOSExportView()
        .environmentObject(EditorViewModel())
}
