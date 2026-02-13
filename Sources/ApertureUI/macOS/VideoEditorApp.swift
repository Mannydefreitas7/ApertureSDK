import SwiftUI

@main
struct VideoEditorApp: App {
    @StateObject private var viewModel = EditorViewModel()

    var body: some Scene {
        WindowGroup {
            MainEditorView()
                .environmentObject(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // 文件菜单
            CommandGroup(replacing: .newItem) {
                Button("新建项目") {
                    // TODO: 新建项目
                }
                .keyboardShortcut("n")

                Button("打开项目...") {
                    // TODO: 打开项目
                }
                .keyboardShortcut("o")

                Divider()

                Button("导入媒体...") {
                    viewModel.showingImportPanel = true
                }
                .keyboardShortcut("i")

                Divider()

                Button("导出视频...") {
                    viewModel.showingExportPanel = true
                }
                .keyboardShortcut("e")
            }

            // 编辑菜单
            CommandGroup(replacing: .undoRedo) {
                Button("撤销") {
                    viewModel.undo()
                }
                .keyboardShortcut("z")

                Button("重做") {
                    viewModel.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])

                Divider()

                Button("删除") {
                    viewModel.deleteSelectedClip()
                }
                .keyboardShortcut(.delete)

                Button("分割") {
                    viewModel.splitSelectedClip()
                }
                .keyboardShortcut("b")
            }

            // 播放菜单
            CommandMenu("播放") {
                Button("播放/暂停") {
                    viewModel.engine.togglePlayback()
                }
                .keyboardShortcut(" ", modifiers: [])

                Divider()

                Button("跳转到开头") {
                    viewModel.engine.seekToBeginning()
                }
                .keyboardShortcut(.home)

                Button("跳转到结尾") {
                    viewModel.engine.seekToEnd()
                }
                .keyboardShortcut(.end)

                Divider()

                Button("后退 1 秒") {
                    viewModel.engine.stepBackward(seconds: 1)
                }
                .keyboardShortcut(.leftArrow)

                Button("前进 1 秒") {
                    viewModel.engine.stepForward(seconds: 1)
                }
                .keyboardShortcut(.rightArrow)
            }
        }

        // 设置窗口
        Settings {
            SettingsView()
        }
    }
}

/// 设置视图
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            ExportSettingsView()
                .tabItem {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("defaultResolution") var defaultResolution = "1080p"
    @AppStorage("defaultFrameRate") var defaultFrameRate = 30.0

    var body: some View {
        Form {
            Picker("默认分辨率", selection: $defaultResolution) {
                Text("720p").tag("720p")
                Text("1080p").tag("1080p")
                Text("4K").tag("4K")
            }

            Picker("默认帧率", selection: $defaultFrameRate) {
                Text("24 fps").tag(24.0)
                Text("30 fps").tag(30.0)
                Text("60 fps").tag(60.0)
            }
        }
        .padding()
    }
}

struct ExportSettingsView: View {
    @AppStorage("defaultExportPreset") var defaultExportPreset = "highest"

    var body: some View {
        Form {
            Picker("默认导出质量", selection: $defaultExportPreset) {
                Text("低质量").tag("low")
                Text("中等质量").tag("medium")
                Text("高质量").tag("high")
                Text("最高质量").tag("highest")
            }
        }
        .padding()
    }
}
