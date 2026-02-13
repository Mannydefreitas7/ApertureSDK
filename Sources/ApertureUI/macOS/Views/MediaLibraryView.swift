import SwiftUI
import UniformTypeIdentifiers

/// 媒体库视图
struct MediaLibraryView: View {
    @EnvironmentObject var viewModel: EditorViewModel

    @State private var selectedTab: MediaTab = .media
    @State private var searchText: String = ""
    @State private var isDropTargeted: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标签
            HStack(spacing: 0) {
                ForEach(MediaTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .padding(8)

            Divider()

            // 内容
            switch selectedTab {
            case .media:
                MediaContent(searchText: searchText, isDropTargeted: $isDropTargeted)
            case .audio:
                AudioContent()
            case .text:
                TextContent()
            case .effects:
                EffectsContent()
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }

                Task { @MainActor in
                    await viewModel.importMedia(urls: [url])
                }
            }
        }
    }
}

/// 媒体库标签
enum MediaTab: String, CaseIterable {
    case media = "素材"
    case audio = "音频"
    case text = "文字"
    case effects = "特效"

    var icon: String {
        switch self {
        case .media: return "photo.on.rectangle"
        case .audio: return "music.note"
        case .text: return "textformat"
        case .effects: return "sparkles"
        }
    }
}

/// 标签按钮
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

/// 媒体内容
struct MediaContent: View {
    @EnvironmentObject var viewModel: EditorViewModel
    let searchText: String
    @Binding var isDropTargeted: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
    ]

    var filteredMedia: [MediaItem] {
        if searchText.isEmpty {
            return viewModel.mediaLibrary
        }
        return viewModel.mediaLibrary.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        if viewModel.mediaLibrary.isEmpty {
            // 空状态
            VStack(spacing: 16) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor : Color.gray.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [8])
                        )
                        .frame(width: 200, height: 150)

                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)

                        Text("拖拽文件到这里")
                            .font(.callout)
                            .foregroundColor(.secondary)

                        Text("或点击导入")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onTapGesture {
                    viewModel.showingImportPanel = true
                }

                Spacer()
            }
        } else {
            // 媒体网格
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    // 导入按钮
                    ImportButton {
                        viewModel.showingImportPanel = true
                    }

                    // 媒体项
                    ForEach(filteredMedia) { item in
                        MediaItemView(item: item)
                            .onTapGesture(count: 2) {
                                Task {
                                    await viewModel.addToTimeline(mediaItem: item)
                                }
                            }
                    }
                }
                .padding(8)
            }
        }
    }
}

/// 导入按钮
struct ImportButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(height: 70)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )

                Text("导入")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// 媒体项视图
struct MediaItemView: View {
    let item: MediaItem
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            // 缩略图
            ZStack {
                if let thumbnail = item.thumbnail {
                    Image(decorative: thumbnail, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 70)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 70)
                        .overlay(
                            Image(systemName: item.type == .video ? "film" : "music.note")
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
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(3)
                                .padding(4)
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? Color.accentColor : Color.clear, lineWidth: 2)
            )

            // 名称
            Text(item.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// 音频内容
struct AudioContent: View {
    var body: some View {
        VStack {
            Spacer()
            Text("音频库")
                .foregroundColor(.secondary)
            Text("即将推出")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

/// 文字内容
struct TextContent: View {
    var body: some View {
        VStack {
            Spacer()
            Text("文字模板")
                .foregroundColor(.secondary)
            Text("即将推出")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

/// 特效内容
struct EffectsContent: View {
    var body: some View {
        VStack {
            Spacer()
            Text("特效库")
                .foregroundColor(.secondary)
            Text("即将推出")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

#Preview {
    MediaLibraryView()
        .environmentObject(EditorViewModel())
        .frame(width: 280, height: 600)
}
