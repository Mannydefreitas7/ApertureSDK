//
//  UIEnhancements.swift
//  VideoEditor
//
//  界面和交互增强模块 - 快捷键、布局、主题、多显示器、手势
//

import SwiftUI
import Combine
#if canImport(AppKit)
import AppKit
import Carbon
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 快捷键系统

/// 快捷键定义
struct KeyboardShortcut: Identifiable, Codable, Hashable {
    let id: UUID
    var action: ShortcutAction
    var keyCode: UInt16
    var modifiers: KeyModifiers
    var isEnabled: Bool
    var category: ShortcutCategory

    init(action: ShortcutAction, keyCode: UInt16, modifiers: KeyModifiers, category: ShortcutCategory = .general) {
        self.id = UUID()
        self.action = action
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.isEnabled = true
        self.category = category
    }

    var displayString: String {
        var parts: [String] = []

        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        parts.append(keyCodeToString(keyCode))

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x24: "⏎", 0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K",
            0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N",
            0x2E: "M", 0x2F: ".", 0x30: "⇥", 0x31: "Space", 0x33: "⌫",
            0x35: "⎋", 0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            0x73: "Home", 0x77: "End", 0x74: "PgUp", 0x79: "PgDn"
        ]
        return keyMap[keyCode] ?? "?"
    }
}

/// 快捷键修饰符
struct KeyModifiers: OptionSet, Codable, Hashable {
    let rawValue: UInt

    static let control = KeyModifiers(rawValue: 1 << 0)
    static let option = KeyModifiers(rawValue: 1 << 1)
    static let shift = KeyModifiers(rawValue: 1 << 2)
    static let command = KeyModifiers(rawValue: 1 << 3)

    static let none = KeyModifiers([])
}

/// 快捷键动作
enum ShortcutAction: String, Codable, CaseIterable {
    // 文件
    case newProject = "新建项目"
    case openProject = "打开项目"
    case saveProject = "保存项目"
    case saveProjectAs = "另存为"
    case exportVideo = "导出视频"
    case importMedia = "导入媒体"

    // 编辑
    case undo = "撤销"
    case redo = "重做"
    case cut = "剪切"
    case copy = "复制"
    case paste = "粘贴"
    case delete = "删除"
    case selectAll = "全选"
    case deselectAll = "取消选择"
    case duplicate = "复制片段"

    // 播放
    case playPause = "播放/暂停"
    case stop = "停止"
    case jumpToStart = "跳到开头"
    case jumpToEnd = "跳到结尾"
    case frameForward = "下一帧"
    case frameBackward = "上一帧"
    case jumpForward5s = "前进5秒"
    case jumpBackward5s = "后退5秒"
    case toggleLoop = "循环播放"
    case speedUp = "加速"
    case speedDown = "减速"

    // 时间线
    case splitClip = "分割片段"
    case rippleDelete = "波纹删除"
    case insertGap = "插入间隙"
    case nudgeLeft = "微移左"
    case nudgeRight = "微移右"
    case zoomIn = "放大"
    case zoomOut = "缩小"
    case zoomToFit = "适合窗口"
    case snapToggle = "吸附开关"
    case magneticTimeline = "磁性时间线"

    // 标记
    case markIn = "标记入点"
    case markOut = "标记出点"
    case clearMarks = "清除标记"
    case addMarker = "添加标记"
    case goToNextMarker = "下一标记"
    case goToPrevMarker = "上一标记"

    // 视图
    case toggleFullscreen = "全屏"
    case toggleTimeline = "显示时间线"
    case toggleInspector = "显示检查器"
    case toggleLibrary = "显示媒体库"
    case toggleEffects = "显示效果面板"
    case focusPreview = "聚焦预览"
    case focusTimeline = "聚焦时间线"

    // 工具
    case selectionTool = "选择工具"
    case razorTool = "剃刀工具"
    case handTool = "手形工具"
    case zoomTool = "缩放工具"
    case cropTool = "裁剪工具"
    case textTool = "文字工具"
}

/// 快捷键分类
enum ShortcutCategory: String, Codable, CaseIterable {
    case general = "通用"
    case file = "文件"
    case edit = "编辑"
    case playback = "播放"
    case timeline = "时间线"
    case markers = "标记"
    case view = "视图"
    case tools = "工具"
}

/// 快捷键管理器
class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()

    @Published var shortcuts: [KeyboardShortcut] = []
    @Published var isRecording: Bool = false

    var actionHandler: ((ShortcutAction) -> Void)?

    private var eventMonitor: Any?

    init() {
        loadDefaultShortcuts()
        setupEventMonitor()
    }

    /// 加载默认快捷键
    private func loadDefaultShortcuts() {
        shortcuts = [
            // 文件
            KeyboardShortcut(action: .newProject, keyCode: 0x2D, modifiers: .command, category: .file),
            KeyboardShortcut(action: .openProject, keyCode: 0x1F, modifiers: .command, category: .file),
            KeyboardShortcut(action: .saveProject, keyCode: 0x01, modifiers: .command, category: .file),
            KeyboardShortcut(action: .saveProjectAs, keyCode: 0x01, modifiers: [.command, .shift], category: .file),
            KeyboardShortcut(action: .exportVideo, keyCode: 0x0E, modifiers: .command, category: .file),
            KeyboardShortcut(action: .importMedia, keyCode: 0x22, modifiers: .command, category: .file),

            // 编辑
            KeyboardShortcut(action: .undo, keyCode: 0x06, modifiers: .command, category: .edit),
            KeyboardShortcut(action: .redo, keyCode: 0x06, modifiers: [.command, .shift], category: .edit),
            KeyboardShortcut(action: .cut, keyCode: 0x07, modifiers: .command, category: .edit),
            KeyboardShortcut(action: .copy, keyCode: 0x08, modifiers: .command, category: .edit),
            KeyboardShortcut(action: .paste, keyCode: 0x09, modifiers: .command, category: .edit),
            KeyboardShortcut(action: .delete, keyCode: 0x33, modifiers: .none, category: .edit),
            KeyboardShortcut(action: .selectAll, keyCode: 0x00, modifiers: .command, category: .edit),
            KeyboardShortcut(action: .duplicate, keyCode: 0x02, modifiers: .command, category: .edit),

            // 播放
            KeyboardShortcut(action: .playPause, keyCode: 0x31, modifiers: .none, category: .playback),
            KeyboardShortcut(action: .stop, keyCode: 0x28, modifiers: .none, category: .playback),
            KeyboardShortcut(action: .jumpToStart, keyCode: 0x73, modifiers: .none, category: .playback),
            KeyboardShortcut(action: .jumpToEnd, keyCode: 0x77, modifiers: .none, category: .playback),
            KeyboardShortcut(action: .frameForward, keyCode: 0x7C, modifiers: .none, category: .playback),
            KeyboardShortcut(action: .frameBackward, keyCode: 0x7B, modifiers: .none, category: .playback),
            KeyboardShortcut(action: .jumpForward5s, keyCode: 0x7C, modifiers: .shift, category: .playback),
            KeyboardShortcut(action: .jumpBackward5s, keyCode: 0x7B, modifiers: .shift, category: .playback),
            KeyboardShortcut(action: .toggleLoop, keyCode: 0x25, modifiers: .command, category: .playback),

            // 时间线
            KeyboardShortcut(action: .splitClip, keyCode: 0x0B, modifiers: .command, category: .timeline),
            KeyboardShortcut(action: .rippleDelete, keyCode: 0x33, modifiers: .shift, category: .timeline),
            KeyboardShortcut(action: .zoomIn, keyCode: 0x18, modifiers: .command, category: .timeline),
            KeyboardShortcut(action: .zoomOut, keyCode: 0x1B, modifiers: .command, category: .timeline),
            KeyboardShortcut(action: .zoomToFit, keyCode: 0x06, modifiers: [.command, .shift], category: .timeline),
            KeyboardShortcut(action: .snapToggle, keyCode: 0x2D, modifiers: .none, category: .timeline),

            // 标记
            KeyboardShortcut(action: .markIn, keyCode: 0x22, modifiers: .none, category: .markers),
            KeyboardShortcut(action: .markOut, keyCode: 0x1F, modifiers: .none, category: .markers),
            KeyboardShortcut(action: .clearMarks, keyCode: 0x07, modifiers: .option, category: .markers),
            KeyboardShortcut(action: .addMarker, keyCode: 0x2E, modifiers: .none, category: .markers),

            // 视图
            KeyboardShortcut(action: .toggleFullscreen, keyCode: 0x03, modifiers: [.command, .control], category: .view),
            KeyboardShortcut(action: .toggleTimeline, keyCode: 0x11, modifiers: .command, category: .view),
            KeyboardShortcut(action: .toggleInspector, keyCode: 0x22, modifiers: [.command, .option], category: .view),
            KeyboardShortcut(action: .toggleLibrary, keyCode: 0x25, modifiers: [.command, .option], category: .view),

            // 工具
            KeyboardShortcut(action: .selectionTool, keyCode: 0x00, modifiers: .none, category: .tools),
            KeyboardShortcut(action: .razorTool, keyCode: 0x0B, modifiers: .none, category: .tools),
            KeyboardShortcut(action: .handTool, keyCode: 0x04, modifiers: .none, category: .tools),
            KeyboardShortcut(action: .zoomTool, keyCode: 0x06, modifiers: .none, category: .tools),
            KeyboardShortcut(action: .textTool, keyCode: 0x11, modifiers: .none, category: .tools)
        ]
    }

    /// 设置事件监听
    private func setupEventMonitor() {
        #if canImport(AppKit)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
        #endif
    }

    #if canImport(AppKit)
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        var modifiers = KeyModifiers.none

        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }

        if let shortcut = shortcuts.first(where: { $0.keyCode == keyCode && $0.modifiers == modifiers && $0.isEnabled }) {
            actionHandler?(shortcut.action)
            return true
        }

        return false
    }
    #endif

    /// 更新快捷键
    func updateShortcut(_ shortcut: KeyboardShortcut, keyCode: UInt16, modifiers: KeyModifiers) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].keyCode = keyCode
            shortcuts[index].modifiers = modifiers
            saveShortcuts()
        }
    }

    /// 重置为默认
    func resetToDefault() {
        loadDefaultShortcuts()
        saveShortcuts()
    }

    /// 导出快捷键配置
    func exportShortcuts() -> Data? {
        return try? JSONEncoder().encode(shortcuts)
    }

    /// 导入快捷键配置
    func importShortcuts(from data: Data) {
        if let imported = try? JSONDecoder().decode([KeyboardShortcut].self, from: data) {
            shortcuts = imported
            saveShortcuts()
        }
    }

    private func saveShortcuts() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: "keyboard_shortcuts")
        }
    }

    deinit {
        #if canImport(AppKit)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        #endif
    }
}

// MARK: - 界面布局系统

/// 布局配置
struct WorkspaceLayout: Identifiable, Codable {
    let id: UUID
    var name: String
    var panels: [PanelConfig]
    var isDefault: Bool

    init(name: String, panels: [PanelConfig] = [], isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.panels = panels
        self.isDefault = isDefault
    }
}

/// 面板配置
struct PanelConfig: Identifiable, Codable {
    let id: UUID
    var panelType: PanelType
    var position: PanelPosition
    var size: CGSize
    var isVisible: Bool
    var isCollapsed: Bool
    var tabs: [PanelTab]

    init(panelType: PanelType, position: PanelPosition, size: CGSize = CGSize(width: 300, height: 400)) {
        self.id = UUID()
        self.panelType = panelType
        self.position = position
        self.size = size
        self.isVisible = true
        self.isCollapsed = false
        self.tabs = []
    }
}

/// 面板类型
enum PanelType: String, Codable, CaseIterable {
    case preview = "预览"
    case timeline = "时间线"
    case inspector = "检查器"
    case mediaLibrary = "媒体库"
    case effects = "效果"
    case audio = "音频"
    case colors = "颜色"
    case text = "文字"
    case transitions = "转场"
    case keyframes = "关键帧"
    case histogram = "直方图"
    case vectorscope = "矢量示波器"
    case waveform = "波形"
}

/// 面板位置
enum PanelPosition: String, Codable {
    case left = "左侧"
    case right = "右侧"
    case top = "顶部"
    case bottom = "底部"
    case center = "中心"
    case floating = "浮动"
}

/// 面板标签页
struct PanelTab: Identifiable, Codable {
    let id: UUID
    var title: String
    var icon: String
    var isActive: Bool
}

/// 布局管理器
class WorkspaceLayoutManager: ObservableObject {
    static let shared = WorkspaceLayoutManager()

    @Published var layouts: [WorkspaceLayout] = []
    @Published var currentLayout: WorkspaceLayout?
    @Published var panelStates: [UUID: PanelState] = [:]

    struct PanelState {
        var frame: CGRect
        var isVisible: Bool
        var isCollapsed: Bool
        var zIndex: Int
    }

    init() {
        loadDefaultLayouts()
    }

    /// 加载默认布局
    private func loadDefaultLayouts() {
        layouts = [
            createDefaultLayout(),
            createEditingLayout(),
            createColorGradingLayout(),
            createAudioEditingLayout(),
            createCompactLayout()
        ]

        currentLayout = layouts.first
    }

    private func createDefaultLayout() -> WorkspaceLayout {
        var layout = WorkspaceLayout(name: "默认", isDefault: true)
        layout.panels = [
            PanelConfig(panelType: .mediaLibrary, position: .left, size: CGSize(width: 300, height: 600)),
            PanelConfig(panelType: .preview, position: .center, size: CGSize(width: 800, height: 450)),
            PanelConfig(panelType: .inspector, position: .right, size: CGSize(width: 300, height: 600)),
            PanelConfig(panelType: .timeline, position: .bottom, size: CGSize(width: 1400, height: 250))
        ]
        return layout
    }

    private func createEditingLayout() -> WorkspaceLayout {
        var layout = WorkspaceLayout(name: "剪辑")
        layout.panels = [
            PanelConfig(panelType: .mediaLibrary, position: .left, size: CGSize(width: 250, height: 500)),
            PanelConfig(panelType: .effects, position: .left, size: CGSize(width: 250, height: 300)),
            PanelConfig(panelType: .preview, position: .center, size: CGSize(width: 900, height: 500)),
            PanelConfig(panelType: .inspector, position: .right, size: CGSize(width: 300, height: 800)),
            PanelConfig(panelType: .timeline, position: .bottom, size: CGSize(width: 1400, height: 300))
        ]
        return layout
    }

    private func createColorGradingLayout() -> WorkspaceLayout {
        var layout = WorkspaceLayout(name: "调色")
        layout.panels = [
            PanelConfig(panelType: .preview, position: .center, size: CGSize(width: 800, height: 450)),
            PanelConfig(panelType: .colors, position: .right, size: CGSize(width: 400, height: 800)),
            PanelConfig(panelType: .histogram, position: .left, size: CGSize(width: 300, height: 200)),
            PanelConfig(panelType: .vectorscope, position: .left, size: CGSize(width: 300, height: 200)),
            PanelConfig(panelType: .waveform, position: .left, size: CGSize(width: 300, height: 200)),
            PanelConfig(panelType: .timeline, position: .bottom, size: CGSize(width: 1400, height: 200))
        ]
        return layout
    }

    private func createAudioEditingLayout() -> WorkspaceLayout {
        var layout = WorkspaceLayout(name: "音频")
        layout.panels = [
            PanelConfig(panelType: .preview, position: .top, size: CGSize(width: 600, height: 300)),
            PanelConfig(panelType: .audio, position: .right, size: CGSize(width: 400, height: 600)),
            PanelConfig(panelType: .timeline, position: .bottom, size: CGSize(width: 1400, height: 400))
        ]
        return layout
    }

    private func createCompactLayout() -> WorkspaceLayout {
        var layout = WorkspaceLayout(name: "紧凑")
        layout.panels = [
            PanelConfig(panelType: .preview, position: .center, size: CGSize(width: 1000, height: 600)),
            PanelConfig(panelType: .timeline, position: .bottom, size: CGSize(width: 1400, height: 200))
        ]
        return layout
    }

    /// 切换布局
    func switchLayout(to layout: WorkspaceLayout) {
        currentLayout = layout
        applyLayout(layout)
    }

    /// 应用布局
    private func applyLayout(_ layout: WorkspaceLayout) {
        panelStates.removeAll()

        for (index, panel) in layout.panels.enumerated() {
            panelStates[panel.id] = PanelState(
                frame: calculateFrame(for: panel),
                isVisible: panel.isVisible,
                isCollapsed: panel.isCollapsed,
                zIndex: index
            )
        }
    }

    private func calculateFrame(for panel: PanelConfig) -> CGRect {
        // 简化的帧计算
        let screenSize = CGSize(width: 1920, height: 1080)

        switch panel.position {
        case .left:
            return CGRect(x: 0, y: 0, width: panel.size.width, height: panel.size.height)
        case .right:
            return CGRect(x: screenSize.width - panel.size.width, y: 0, width: panel.size.width, height: panel.size.height)
        case .top:
            return CGRect(x: 0, y: 0, width: panel.size.width, height: panel.size.height)
        case .bottom:
            return CGRect(x: 0, y: screenSize.height - panel.size.height, width: panel.size.width, height: panel.size.height)
        case .center:
            return CGRect(x: (screenSize.width - panel.size.width) / 2,
                         y: (screenSize.height - panel.size.height) / 2,
                         width: panel.size.width, height: panel.size.height)
        case .floating:
            return CGRect(x: 100, y: 100, width: panel.size.width, height: panel.size.height)
        }
    }

    /// 保存当前布局
    func saveCurrentLayout(as name: String) {
        guard var layout = currentLayout else { return }
        layout.name = name
        layouts.append(layout)
        saveLayouts()
    }

    /// 删除布局
    func deleteLayout(_ layout: WorkspaceLayout) {
        layouts.removeAll { $0.id == layout.id }
        saveLayouts()
    }

    private func saveLayouts() {
        if let data = try? JSONEncoder().encode(layouts) {
            UserDefaults.standard.set(data, forKey: "workspace_layouts")
        }
    }
}

// MARK: - 主题系统

/// 主题
struct AppTheme: Identifiable, Codable {
    let id: UUID
    var name: String
    var isDark: Bool
    var colors: ThemeColors
    var fonts: ThemeFonts
    var isBuiltIn: Bool

    init(name: String, isDark: Bool = true) {
        self.id = UUID()
        self.name = name
        self.isDark = isDark
        self.colors = ThemeColors()
        self.fonts = ThemeFonts()
        self.isBuiltIn = false
    }
}

/// 主题颜色
struct ThemeColors: Codable {
    var background: String = "#1E1E1E"
    var secondaryBackground: String = "#2D2D2D"
    var tertiaryBackground: String = "#3D3D3D"
    var accent: String = "#007AFF"
    var text: String = "#FFFFFF"
    var secondaryText: String = "#AAAAAA"
    var border: String = "#404040"
    var success: String = "#34C759"
    var warning: String = "#FF9500"
    var error: String = "#FF3B30"
    var timeline: String = "#1C1C1E"
    var playhead: String = "#FF0000"
    var selection: String = "#0A84FF"
    var waveform: String = "#00C853"
    var videoTrack: String = "#5856D6"
    var audioTrack: String = "#34C759"

    var backgroundCGColor: CGColor {
        return parseColor(background)
    }

    var accentCGColor: CGColor {
        return parseColor(accent)
    }

    private func parseColor(_ hex: String) -> CGColor {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

/// 主题字体
struct ThemeFonts: Codable {
    var primaryFamily: String = "SF Pro"
    var monoFamily: String = "SF Mono"
    var titleSize: CGFloat = 20
    var bodySize: CGFloat = 14
    var captionSize: CGFloat = 12
    var smallSize: CGFloat = 10
}

/// 主题管理器
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var themes: [AppTheme] = []
    @Published var currentTheme: AppTheme
    @Published var accentColor: Color = .blue

    init() {
        let defaultTheme = ThemeManager.createDefaultDarkTheme()
        self.themes = [
            defaultTheme,
            ThemeManager.createDefaultLightTheme(),
            ThemeManager.createHighContrastTheme(),
            ThemeManager.createMidnightTheme(),
            ThemeManager.createSolarizedTheme()
        ]
        self.currentTheme = defaultTheme
    }

    static func createDefaultDarkTheme() -> AppTheme {
        var theme = AppTheme(name: "暗色", isDark: true)
        theme.isBuiltIn = true
        return theme
    }

    static func createDefaultLightTheme() -> AppTheme {
        var theme = AppTheme(name: "亮色", isDark: false)
        theme.colors.background = "#FFFFFF"
        theme.colors.secondaryBackground = "#F2F2F7"
        theme.colors.tertiaryBackground = "#E5E5EA"
        theme.colors.text = "#000000"
        theme.colors.secondaryText = "#666666"
        theme.colors.border = "#C6C6C8"
        theme.colors.timeline = "#F2F2F7"
        theme.isBuiltIn = true
        return theme
    }

    static func createHighContrastTheme() -> AppTheme {
        var theme = AppTheme(name: "高对比度", isDark: true)
        theme.colors.background = "#000000"
        theme.colors.secondaryBackground = "#1A1A1A"
        theme.colors.text = "#FFFFFF"
        theme.colors.accent = "#00FF00"
        theme.colors.border = "#FFFFFF"
        theme.isBuiltIn = true
        return theme
    }

    static func createMidnightTheme() -> AppTheme {
        var theme = AppTheme(name: "午夜", isDark: true)
        theme.colors.background = "#0A0A14"
        theme.colors.secondaryBackground = "#141428"
        theme.colors.accent = "#6E5AE0"
        theme.isBuiltIn = true
        return theme
    }

    static func createSolarizedTheme() -> AppTheme {
        var theme = AppTheme(name: "Solarized", isDark: true)
        theme.colors.background = "#002B36"
        theme.colors.secondaryBackground = "#073642"
        theme.colors.text = "#839496"
        theme.colors.accent = "#2AA198"
        theme.isBuiltIn = true
        return theme
    }

    /// 切换主题
    func switchTheme(to theme: AppTheme) {
        currentTheme = theme
        applyTheme(theme)
    }

    /// 应用主题
    private func applyTheme(_ theme: AppTheme) {
        #if canImport(AppKit)
        NSApp.appearance = theme.isDark ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        #endif
    }

    /// 创建自定义主题
    func createCustomTheme(name: String, baseTheme: AppTheme) -> AppTheme {
        var newTheme = baseTheme
        newTheme.name = name
        newTheme.isBuiltIn = false
        themes.append(newTheme)
        saveThemes()
        return newTheme
    }

    /// 更新主题颜色
    func updateThemeColor(_ theme: AppTheme, colorKey: String, value: String) {
        guard let index = themes.firstIndex(where: { $0.id == theme.id }) else { return }

        switch colorKey {
        case "background": themes[index].colors.background = value
        case "accent": themes[index].colors.accent = value
        case "text": themes[index].colors.text = value
        default: break
        }

        if currentTheme.id == theme.id {
            currentTheme = themes[index]
            applyTheme(currentTheme)
        }

        saveThemes()
    }

    /// 删除主题
    func deleteTheme(_ theme: AppTheme) {
        guard !theme.isBuiltIn else { return }
        themes.removeAll { $0.id == theme.id }
        saveThemes()
    }

    private func saveThemes() {
        if let data = try? JSONEncoder().encode(themes) {
            UserDefaults.standard.set(data, forKey: "app_themes")
        }
    }
}

// MARK: - 多显示器支持

/// 显示器信息
struct DisplayInfo: Identifiable {
    let id: CGDirectDisplayID
    var name: String
    var bounds: CGRect
    var scaleFactor: CGFloat
    var isMain: Bool
    var colorSpace: String
    var refreshRate: Int
}

/// 窗口配置
struct WindowConfiguration: Identifiable, Codable {
    let id: UUID
    var windowType: WindowType
    var displayIndex: Int
    var frame: CGRect
    var isFullscreen: Bool

    enum WindowType: String, Codable {
        case main = "主窗口"
        case preview = "预览窗口"
        case timeline = "时间线窗口"
        case inspector = "检查器窗口"
        case effects = "效果窗口"
        case reference = "参考监视器"
    }
}

/// 多显示器管理器
class MultiDisplayManager: ObservableObject {
    static let shared = MultiDisplayManager()

    @Published var displays: [DisplayInfo] = []
    @Published var windowConfigurations: [WindowConfiguration] = []
    @Published var isMultiDisplayMode: Bool = false

    init() {
        refreshDisplays()
        setupDisplayNotifications()
    }

    /// 刷新显示器列表
    func refreshDisplays() {
        displays.removeAll()

        #if canImport(AppKit)
        for screen in NSScreen.screens {
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0

            let info = DisplayInfo(
                id: displayID,
                name: screen.localizedName,
                bounds: screen.frame,
                scaleFactor: screen.backingScaleFactor,
                isMain: screen == NSScreen.main,
                colorSpace: screen.colorSpace?.localizedName ?? "Unknown",
                refreshRate: Int(CGDisplayCopyDisplayMode(displayID)?.refreshRate ?? 60)
            )
            displays.append(info)
        }
        #endif
    }

    /// 设置显示器通知
    private func setupDisplayNotifications() {
        #if canImport(AppKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        #endif
    }

    @objc private func displaysChanged() {
        refreshDisplays()
    }

    /// 打开预览窗口到指定显示器
    func openPreviewWindow(on displayIndex: Int) {
        guard displayIndex < displays.count else { return }
        let display = displays[displayIndex]

        let config = WindowConfiguration(
            id: UUID(),
            windowType: .preview,
            displayIndex: displayIndex,
            frame: display.bounds,
            isFullscreen: true
        )

        windowConfigurations.append(config)
        createWindow(for: config)
    }

    /// 创建窗口
    private func createWindow(for config: WindowConfiguration) {
        #if canImport(AppKit)
        let contentRect = config.frame

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = config.windowType.rawValue
        window.makeKeyAndOrderFront(nil)

        if config.isFullscreen {
            window.toggleFullScreen(nil)
        }
        #endif
    }

    /// 保存窗口配置
    func saveWindowConfiguration() {
        if let data = try? JSONEncoder().encode(windowConfigurations) {
            UserDefaults.standard.set(data, forKey: "window_configurations")
        }
    }

    /// 恢复窗口配置
    func restoreWindowConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "window_configurations"),
           let configs = try? JSONDecoder().decode([WindowConfiguration].self, from: data) {
            windowConfigurations = configs
            for config in configs {
                createWindow(for: config)
            }
        }
    }
}

// MARK: - 手势系统

/// 手势类型
enum GestureType: String, CaseIterable, Codable {
    case pinch = "捏合"
    case rotate = "旋转"
    case pan = "平移"
    case swipe = "滑动"
    case tap = "点击"
    case doubleTap = "双击"
    case longPress = "长按"
    case threeFingerSwipe = "三指滑动"
    case fourFingerSwipe = "四指滑动"
}

/// 手势动作绑定
struct GestureBinding: Identifiable, Codable {
    let id: UUID
    var gestureType: GestureType
    var action: GestureAction
    var area: GestureArea
    var isEnabled: Bool

    enum GestureAction: String, Codable, CaseIterable {
        case zoomTimeline = "缩放时间线"
        case scrollTimeline = "滚动时间线"
        case zoomPreview = "缩放预览"
        case panPreview = "平移预览"
        case rotateClip = "旋转片段"
        case scrub = "擦洗"
        case markIn = "标记入点"
        case markOut = "标记出点"
        case playPause = "播放/暂停"
        case split = "分割"
        case delete = "删除"
        case undo = "撤销"
        case redo = "重做"
        case showEffects = "显示效果"
        case showTransitions = "显示转场"
    }

    enum GestureArea: String, Codable, CaseIterable {
        case timeline = "时间线"
        case preview = "预览"
        case inspector = "检查器"
        case mediaLibrary = "媒体库"
        case global = "全局"
    }
}

/// 手势配置
struct GestureConfiguration: Codable {
    var trackpadSensitivity: Float = 1.0
    var mouseSensitivity: Float = 1.0
    var scrollDirection: ScrollDirection = .natural
    var enableMomentum: Bool = true
    var enableZoom: Bool = true
    var enableRotate: Bool = true

    enum ScrollDirection: String, Codable {
        case natural = "自然"
        case inverted = "反向"
    }
}

/// 手势管理器
class GestureManager: ObservableObject {
    static let shared = GestureManager()

    @Published var bindings: [GestureBinding] = []
    @Published var configuration: GestureConfiguration = GestureConfiguration()

    var gestureHandler: ((GestureBinding.GestureAction) -> Void)?

    init() {
        loadDefaultBindings()
    }

    /// 加载默认手势绑定
    private func loadDefaultBindings() {
        bindings = [
            GestureBinding(id: UUID(), gestureType: .pinch, action: .zoomTimeline, area: .timeline, isEnabled: true),
            GestureBinding(id: UUID(), gestureType: .pan, action: .scrollTimeline, area: .timeline, isEnabled: true),
            GestureBinding(id: UUID(), gestureType: .pinch, action: .zoomPreview, area: .preview, isEnabled: true),
            GestureBinding(id: UUID(), gestureType: .pan, action: .panPreview, area: .preview, isEnabled: true),
            GestureBinding(id: UUID(), gestureType: .rotate, action: .rotateClip, area: .preview, isEnabled: true),
            GestureBinding(id: UUID(), gestureType: .doubleTap, action: .playPause, area: .preview, isEnabled: true),
            GestureBinding(id: UUID(), gestureType: .swipe, action: .scrub, area: .timeline, isEnabled: true),
            GestureBinding(id: UUID(), gestureType: .threeFingerSwipe, action: .undo, area: .global, isEnabled: true)
        ]
    }

    /// 处理手势
    func handleGesture(_ type: GestureType, in area: GestureBinding.GestureArea, value: Any? = nil) {
        guard let binding = bindings.first(where: {
            $0.gestureType == type && $0.area == area && $0.isEnabled
        }) else { return }

        gestureHandler?(binding.action)
    }

    /// 更新手势绑定
    func updateBinding(_ binding: GestureBinding, action: GestureBinding.GestureAction) {
        if let index = bindings.firstIndex(where: { $0.id == binding.id }) {
            bindings[index].action = action
            saveBindings()
        }
    }

    /// 重置为默认
    func resetToDefault() {
        loadDefaultBindings()
        configuration = GestureConfiguration()
        saveBindings()
    }

    private func saveBindings() {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: "gesture_bindings")
        }
    }
}

// MARK: - 触控栏支持 (macOS)

#if canImport(AppKit)
/// 触控栏管理器
class TouchBarManager: ObservableObject {
    static let shared = TouchBarManager()

    @Published var currentMode: TouchBarMode = .default
    @Published var isEnabled: Bool = true

    enum TouchBarMode: String, CaseIterable {
        case `default` = "默认"
        case editing = "编辑"
        case playback = "播放"
        case color = "调色"
        case audio = "音频"
        case text = "文字"
    }

    func switchMode(to mode: TouchBarMode) {
        currentMode = mode
        // 更新触控栏内容
    }
}
#endif

// MARK: - 拖放管理器

/// 拖放项目类型
enum DragItemType: String {
    case mediaClip = "media.clip"
    case effect = "effect"
    case transition = "transition"
    case text = "text"
    case sticker = "sticker"
    case audio = "audio"
}

/// 拖放信息
struct DragInfo {
    var itemType: DragItemType
    var itemId: UUID
    var sourceLocation: CGPoint
    var currentLocation: CGPoint
    var data: Any?
}

/// 拖放管理器
class DragDropManager: ObservableObject {
    static let shared = DragDropManager()

    @Published var isDragging: Bool = false
    @Published var currentDragInfo: DragInfo?
    @Published var dropTargets: [UUID: CGRect] = [:]
    @Published var activeDropTarget: UUID?

    var onDrop: ((DragInfo, UUID) -> Bool)?

    /// 开始拖拽
    func beginDrag(type: DragItemType, itemId: UUID, location: CGPoint, data: Any? = nil) {
        currentDragInfo = DragInfo(
            itemType: type,
            itemId: itemId,
            sourceLocation: location,
            currentLocation: location,
            data: data
        )
        isDragging = true
    }

    /// 更新拖拽位置
    func updateDrag(to location: CGPoint) {
        currentDragInfo?.currentLocation = location

        // 检查放置目标
        activeDropTarget = nil
        for (targetId, frame) in dropTargets {
            if frame.contains(location) {
                activeDropTarget = targetId
                break
            }
        }
    }

    /// 结束拖拽
    func endDrag() -> Bool {
        guard let info = currentDragInfo, let target = activeDropTarget else {
            cancelDrag()
            return false
        }

        let success = onDrop?(info, target) ?? false

        isDragging = false
        currentDragInfo = nil
        activeDropTarget = nil

        return success
    }

    /// 取消拖拽
    func cancelDrag() {
        isDragging = false
        currentDragInfo = nil
        activeDropTarget = nil
    }

    /// 注册放置目标
    func registerDropTarget(id: UUID, frame: CGRect) {
        dropTargets[id] = frame
    }

    /// 注销放置目标
    func unregisterDropTarget(id: UUID) {
        dropTargets.removeValue(forKey: id)
    }
}

// MARK: - 上下文菜单

/// 上下文菜单项
struct ContextMenuItem: Identifiable {
    let id: UUID
    var title: String
    var icon: String?
    var shortcut: String?
    var isEnabled: Bool
    var isSeparator: Bool
    var children: [ContextMenuItem]?
    var action: (() -> Void)?

    init(title: String, icon: String? = nil, shortcut: String? = nil, isEnabled: Bool = true, action: (() -> Void)? = nil) {
        self.id = UUID()
        self.title = title
        self.icon = icon
        self.shortcut = shortcut
        self.isEnabled = isEnabled
        self.isSeparator = false
        self.children = nil
        self.action = action
    }

    static func separator() -> ContextMenuItem {
        var item = ContextMenuItem(title: "")
        item.isSeparator = true
        return item
    }
}

/// 上下文菜单管理器
class ContextMenuManager: ObservableObject {
    static let shared = ContextMenuManager()

    /// 获取时间线上下文菜单
    func getTimelineContextMenu(for clipId: UUID?) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []

        if clipId != nil {
            items.append(ContextMenuItem(title: "剪切", icon: "scissors", shortcut: "⌘X"))
            items.append(ContextMenuItem(title: "复制", icon: "doc.on.doc", shortcut: "⌘C"))
            items.append(ContextMenuItem(title: "粘贴", icon: "doc.on.clipboard", shortcut: "⌘V"))
            items.append(.separator())
            items.append(ContextMenuItem(title: "分割", icon: "divide", shortcut: "⌘B"))
            items.append(ContextMenuItem(title: "删除", icon: "trash", shortcut: "⌫"))
            items.append(.separator())
            items.append(ContextMenuItem(title: "速度/时长", icon: "speedometer"))
            items.append(ContextMenuItem(title: "反转片段", icon: "arrow.uturn.backward"))
            items.append(ContextMenuItem(title: "冻结帧", icon: "camera"))
            items.append(.separator())
            items.append(ContextMenuItem(title: "分离音频", icon: "waveform"))
            items.append(ContextMenuItem(title: "添加效果", icon: "sparkles"))
        } else {
            items.append(ContextMenuItem(title: "粘贴", icon: "doc.on.clipboard", shortcut: "⌘V"))
            items.append(.separator())
            items.append(ContextMenuItem(title: "添加标记", icon: "flag", shortcut: "M"))
            items.append(ContextMenuItem(title: "放大", icon: "plus.magnifyingglass", shortcut: "⌘+"))
            items.append(ContextMenuItem(title: "缩小", icon: "minus.magnifyingglass", shortcut: "⌘-"))
        }

        return items
    }

    /// 获取媒体库上下文菜单
    func getMediaLibraryContextMenu(for itemId: UUID?) -> [ContextMenuItem] {
        var items: [ContextMenuItem] = []

        if itemId != nil {
            items.append(ContextMenuItem(title: "添加到时间线", icon: "plus.circle"))
            items.append(ContextMenuItem(title: "在Finder中显示", icon: "folder"))
            items.append(.separator())
            items.append(ContextMenuItem(title: "重命名", icon: "pencil"))
            items.append(ContextMenuItem(title: "删除", icon: "trash"))
            items.append(.separator())
            items.append(ContextMenuItem(title: "添加标签", icon: "tag"))
            items.append(ContextMenuItem(title: "标记为收藏", icon: "heart"))
        } else {
            items.append(ContextMenuItem(title: "导入媒体", icon: "square.and.arrow.down", shortcut: "⌘I"))
            items.append(ContextMenuItem(title: "新建文件夹", icon: "folder.badge.plus"))
            items.append(.separator())
            items.append(ContextMenuItem(title: "排序方式", icon: "arrow.up.arrow.down"))
            items.append(ContextMenuItem(title: "显示方式", icon: "square.grid.2x2"))
        }

        return items
    }
}
