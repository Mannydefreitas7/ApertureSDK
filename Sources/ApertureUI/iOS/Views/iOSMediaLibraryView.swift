import SwiftUI
import PhotosUI

/// iOS 媒体库视图
struct iOSMediaLibraryView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingFilePicker = false

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 导入选项
            HStack(spacing: 16) {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .any(of: [.videos, .images])
                ) {
                    ImportOptionButton(icon: "photo.on.rectangle", label: "相册")
                }

                Button(action: { showingFilePicker = true }) {
                    ImportOptionButton(icon: "folder", label: "文件")
                }
            }
            .padding()

            Divider()

            // 媒体网格
            if viewModel.mediaLibrary.isEmpty {
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("暂无素材")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("点击上方按钮导入视频或图片")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(viewModel.mediaLibrary) { item in
                            iOSMediaItemView(item: item)
                                .onTapGesture {
                                    Task {
                                        await viewModel.addToTimeline(mediaItem: item)
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                await loadSelectedPhotos(newItems)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.movie, .audio, .image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task {
                    await viewModel.importMedia(urls: urls)
                }
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                await viewModel.importMedia(urls: [movie.url])
            }
        }
        selectedPhotos = []
    }
}

/// 视频传输类型
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")

            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

/// 导入选项按钮
struct ImportOptionButton: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))

            Text(label)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .foregroundColor(.primary)
    }
}

/// iOS 媒体项视图
struct iOSMediaItemView: View {
    let item: MediaItem

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let thumbnail = item.thumbnail {
                    Image(decorative: thumbnail, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.tertiarySystemBackground))
                        .frame(height: 100)
                        .overlay(
                            Image(systemName: item.type == .video ? "film" : "music.note")
                                .font(.title)
                                .foregroundColor(.secondary)
                        )
                }

                // 时长标签
                if item.type != .image {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(item.durationString)
                                .font(.system(size: 10))
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                .padding(4)
                        }
                    }
                }
            }

            Text(item.name)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    iOSMediaLibraryView()
        .environmentObject(EditorViewModel())
}
