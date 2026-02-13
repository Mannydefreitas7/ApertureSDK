import SwiftUI

@main
struct VideoEditorApp: App {
    @StateObject private var viewModel = EditorViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

/// iOS 主视图
struct ContentView: View {
    @EnvironmentObject var viewModel: EditorViewModel
    @State private var selectedTab: iOSTab = .edit

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 主内容
                switch selectedTab {
                case .edit:
                    iOSEditorView()
                case .media:
                    iOSMediaLibraryView()
                case .export:
                    iOSExportView()
                }
            }
            .navigationTitle(viewModel.engine.project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("导出") {
                        selectedTab = .export
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            // 底部标签栏
            iOSTabBar(selectedTab: $selectedTab)
        }
    }
}

/// iOS 标签
enum iOSTab: String, CaseIterable {
    case edit = "编辑"
    case media = "素材"
    case export = "导出"

    var icon: String {
        switch self {
        case .edit: return "slider.horizontal.3"
        case .media: return "photo.on.rectangle"
        case .export: return "square.and.arrow.up"
        }
    }
}

/// iOS 标签栏
struct iOSTabBar: View {
    @Binding var selectedTab: iOSTab

    var body: some View {
        HStack {
            ForEach(iOSTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(EditorViewModel())
}
