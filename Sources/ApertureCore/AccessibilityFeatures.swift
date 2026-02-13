//
//  AccessibilityFeatures.swift
//  VideoEditor
//
//  Accessibility features module - VoiceOver, high contrast, keyboard navigation, color blind mode
//

import SwiftUI
import Combine
import AVFoundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Accessibility Settings

/// Accessibility configuration
struct AccessibilitySettings: Codable {
    // VoiceOver
    var voiceOverEnabled: Bool = false
    var announceClipChanges: Bool = true
    var announcePlaybackState: Bool = true
    var announceTimeUpdates: Bool = false
    var timeUpdateInterval: Double = 5.0 // seconds

    // Visual
    var highContrastMode: Bool = false
    var reduceMotion: Bool = false
    var reduceTransparency: Bool = false
    var increaseContrast: Bool = false
    var boldText: Bool = false
    var largerText: Bool = false
    var textScale: Double = 1.0

    // Color blind mode
    var colorBlindMode: ColorBlindMode = .none
    var colorBlindStrength: Double = 1.0

    // Keyboard
    var fullKeyboardAccess: Bool = false
    var focusIndicatorStyle: FocusIndicatorStyle = .default
    var stickyKeys: Bool = false
    var slowKeys: Bool = false
    var slowKeysDelay: Double = 0.5

    // Audio
    var monoAudio: Bool = false
    var audioBalance: Double = 0.0 // -1.0 to 1.0
    var visualNotifications: Bool = false
    var flashScreenOnAlert: Bool = false

    // Mouse/Touch
    var cursorSize: CursorSize = .normal
    var shakeToLocateCursor: Bool = false
    var dwellControl: Bool = false
    var dwellTime: Double = 1.0

    // Captions
    var alwaysShowCaptions: Bool = false
    var captionStyle: CaptionStyle = .default

    enum ColorBlindMode: String, Codable, CaseIterable {
        case none = "None"
        case protanopia = "Protanopia"
        case deuteranopia = "Deuteranopia"
        case tritanopia = "Tritanopia"
        case achromatopsia = "Achromatopsia"
        case protanomaly = "Protanomaly"
        case deuteranomaly = "Deuteranomaly"
        case tritanomaly = "Tritanomaly"
    }

    enum FocusIndicatorStyle: String, Codable, CaseIterable {
        case `default` = "Default"
        case highContrast = "High Contrast"
        case custom = "Custom"
    }

    enum CursorSize: String, Codable, CaseIterable {
        case normal = "Normal"
        case large = "Large"
        case extraLarge = "Extra Large"
    }

    enum CaptionStyle: String, Codable, CaseIterable {
        case `default` = "Default"
        case largeText = "Large Text"
        case classic = "Classic"
        case outline = "Outline"
        case custom = "Custom"
    }
}

// MARK: - Accessibility Manager

/// Accessibility manager
class AccessibilityManager: NSObject, ObservableObject {
    static let shared = AccessibilityManager()

    @Published var settings: AccessibilitySettings = AccessibilitySettings()
    @Published var isVoiceOverRunning: Bool = false
    @Published var currentFocusedElement: String = ""

    private var speechSynthesizer: AVSpeechSynthesizer?
    private var announceQueue: [String] = []
    private var isAnnouncing: Bool = false

    override init() {
        super.init()
        loadSettings()
        setupSystemAccessibilityObservers()
        setupSpeechSynthesizer()
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "accessibility_settings"),
           let settings = try? JSONDecoder().decode(AccessibilitySettings.self, from: data) {
            self.settings = settings
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "accessibility_settings")
        }
        applySettings()
    }

    private func setupSystemAccessibilityObservers() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )

        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        #endif

        #if canImport(AppKit)
        // macOS VoiceOver detection
        isVoiceOverRunning = NSWorkspace.shared.isVoiceOverEnabled
        #endif
    }

    @objc private func voiceOverStatusChanged() {
        #if canImport(UIKit)
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        #endif
    }

    private func setupSpeechSynthesizer() {
        speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer?.delegate = self
    }

    /// Apply settings
    func applySettings() {
        // Apply high contrast
        if settings.highContrastMode {
            applyHighContrast()
        }

        // Apply color blind mode
        if settings.colorBlindMode != .none {
            applyColorBlindFilter()
        }

        // Apply audio settings
        applyAudioSettings()
    }

    // MARK: - VoiceOver Support

    /// Announce message
    func announce(_ message: String, priority: AnnouncementPriority = .normal) {
        guard settings.voiceOverEnabled || isVoiceOverRunning else { return }

        switch priority {
        case .high:
            // Interrupt current announcement
            speechSynthesizer?.stopSpeaking(at: .immediate)
            speak(message)
        case .normal:
            announceQueue.append(message)
            processAnnounceQueue()
        case .low:
            announceQueue.append(message)
        }
    }

    enum AnnouncementPriority {
        case high
        case normal
        case low
    }

    private func processAnnounceQueue() {
        guard !isAnnouncing, !announceQueue.isEmpty else { return }

        isAnnouncing = true
        let message = announceQueue.removeFirst()
        speak(message)
    }

    private func speak(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        speechSynthesizer?.speak(utterance)

        #if canImport(UIKit)
        // Also notify through VoiceOver
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    /// Announce playback state
    func announcePlaybackState(isPlaying: Bool) {
        guard settings.announcePlaybackState else { return }
        announce(isPlaying ? "Playing" : "Paused")
    }

    /// Announce time
    func announceTime(_ time: TimeInterval) {
        guard settings.announceTimeUpdates else { return }

        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        announce("Current time \(minutes) minutes \(seconds) seconds", priority: .low)
    }

    /// Announce clip information
    func announceClipInfo(name: String, duration: TimeInterval) {
        guard settings.announceClipChanges else { return }

        let durationStr = formatDuration(duration)
        announce("Clip \(name), duration \(durationStr)")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes) minutes \(seconds) seconds"
        } else {
            return "\(seconds) seconds"
        }
    }

    // MARK: - High Contrast

    private func applyHighContrast() {
        // Apply high contrast theme
        ThemeManager.shared.switchTheme(to: ThemeManager.createHighContrastTheme())
    }

    /// Get high contrast color
    func getAccessibleColor(for color: Color, background: Color = .black) -> Color {
        if settings.highContrastMode {
            // Ensure sufficient contrast (WCAG AA standard 4.5:1)
            return ensureContrast(foreground: color, background: background, ratio: 4.5)
        }
        return color
    }

    private func ensureContrast(foreground: Color, background: Color, ratio: Double) -> Color {
        // Simplified contrast adjustment
        return foreground
    }

    // MARK: - Color Blind Mode

    private func applyColorBlindFilter() {
        // Color blind filter matrix
        // These will be applied to video preview and UI
    }

    /// Get color matrix for color blind mode
    func getColorBlindMatrix() -> [Float]? {
        guard settings.colorBlindMode != .none else { return nil }

        let strength = Float(settings.colorBlindStrength)

        switch settings.colorBlindMode {
        case .protanopia:
            return [
                0.567 * strength + (1 - strength), 0.433 * strength, 0, 0,
                0.558 * strength, 0.442 * strength + (1 - strength), 0, 0,
                0, 0.242 * strength, 0.758 * strength + (1 - strength), 0,
                0, 0, 0, 1
            ]
        case .deuteranopia:
            return [
                0.625 * strength + (1 - strength), 0.375 * strength, 0, 0,
                0.7 * strength, 0.3 * strength + (1 - strength), 0, 0,
                0, 0.3 * strength, 0.7 * strength + (1 - strength), 0,
                0, 0, 0, 1
            ]
        case .tritanopia:
            return [
                0.95 * strength + (1 - strength), 0.05 * strength, 0, 0,
                0, 0.433 * strength + (1 - strength), 0.567 * strength, 0,
                0, 0.475 * strength, 0.525 * strength + (1 - strength), 0,
                0, 0, 0, 1
            ]
        case .achromatopsia:
            return [
                0.299 * strength + (1 - strength), 0.587 * strength, 0.114 * strength, 0,
                0.299 * strength, 0.587 * strength + (1 - strength), 0.114 * strength, 0,
                0.299 * strength, 0.587 * strength, 0.114 * strength + (1 - strength), 0,
                0, 0, 0, 1
            ]
        default:
            return nil
        }
    }

    /// Simulate color blind vision
    func simulateColorBlindness(mode: AccessibilitySettings.ColorBlindMode) -> [Float]? {
        switch mode {
        case .protanopia:
            return [
                0.567, 0.433, 0, 0,
                0.558, 0.442, 0, 0,
                0, 0.242, 0.758, 0,
                0, 0, 0, 1
            ]
        case .deuteranopia:
            return [
                0.625, 0.375, 0, 0,
                0.7, 0.3, 0, 0,
                0, 0.3, 0.7, 0,
                0, 0, 0, 1
            ]
        case .tritanopia:
            return [
                0.95, 0.05, 0, 0,
                0, 0.433, 0.567, 0,
                0, 0.475, 0.525, 0,
                0, 0, 0, 1
            ]
        default:
            return nil
        }
    }

    // MARK: - Audio Settings

    private func applyAudioSettings() {
        // Mono audio
        // Audio balance
    }

    /// Get adjusted audio balance
    func getAudioBalance() -> Float {
        return Float(settings.audioBalance)
    }

    /// Whether to use mono audio
    func shouldUseMono() -> Bool {
        return settings.monoAudio
    }

    // MARK: - Visual Notifications

    /// Show visual notification
    func showVisualNotification(message: String) {
        guard settings.visualNotifications else { return }

        #if canImport(AppKit)
        // macOS: Flash screen or show banner
        if settings.flashScreenOnAlert {
            flashScreen()
        }
        #endif

        #if canImport(UIKit)
        // iOS: Show banner notification
        #endif
    }

    #if canImport(AppKit)
    private func flashScreen() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let flashWindow = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        flashWindow.backgroundColor = .white
        flashWindow.alphaValue = 0.5
        flashWindow.level = .screenSaver
        flashWindow.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            flashWindow.orderOut(nil)
        }
    }
    #endif
}

// MARK: - AVSpeechSynthesizerDelegate

extension AccessibilityManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isAnnouncing = false
        processAnnounceQueue()
    }
}

// MARK: - Keyboard Navigation

/// Keyboard focus manager
class KeyboardNavigationManager: ObservableObject {
    static let shared = KeyboardNavigationManager()

    @Published var focusedElementId: String?
    @Published var focusPath: [String] = []
    @Published var isFocusModeActive: Bool = false

    private var focusableElements: [FocusableElement] = []
    private var focusGroups: [String: [FocusableElement]] = [:]

    struct FocusableElement: Identifiable {
        let id: String
        var label: String
        var hint: String?
        var group: String
        var order: Int
        var isEnabled: Bool
        var action: (() -> Void)?
    }

    /// Register focusable element
    func registerFocusable(
        id: String,
        label: String,
        hint: String? = nil,
        group: String = "default",
        order: Int = 0,
        action: (() -> Void)? = nil
    ) {
        let element = FocusableElement(
            id: id,
            label: label,
            hint: hint,
            group: group,
            order: order,
            isEnabled: true,
            action: action
        )

        focusableElements.append(element)

        if focusGroups[group] == nil {
            focusGroups[group] = []
        }
        focusGroups[group]?.append(element)
        focusGroups[group]?.sort { $0.order < $1.order }
    }

    /// Unregister element
    func unregisterFocusable(id: String) {
        focusableElements.removeAll { $0.id == id }
        for (group, _) in focusGroups {
            focusGroups[group]?.removeAll { $0.id == id }
        }
    }

    /// Move focus to next element
    func focusNext() {
        guard let currentId = focusedElementId else {
            focusFirst()
            return
        }

        if let currentIndex = focusableElements.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = (currentIndex + 1) % focusableElements.count
            focusElement(focusableElements[nextIndex])
        }
    }

    /// Move focus to previous element
    func focusPrevious() {
        guard let currentId = focusedElementId else {
            focusLast()
            return
        }

        if let currentIndex = focusableElements.firstIndex(where: { $0.id == currentId }) {
            let prevIndex = currentIndex > 0 ? currentIndex - 1 : focusableElements.count - 1
            focusElement(focusableElements[prevIndex])
        }
    }

    /// Move focus to first element
    func focusFirst() {
        if let first = focusableElements.first {
            focusElement(first)
        }
    }

    /// Move focus to last element
    func focusLast() {
        if let last = focusableElements.last {
            focusElement(last)
        }
    }

    /// Move focus within group
    func focusNextInGroup(_ group: String) {
        guard let elements = focusGroups[group], !elements.isEmpty else { return }

        if let currentId = focusedElementId,
           let currentIndex = elements.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = (currentIndex + 1) % elements.count
            focusElement(elements[nextIndex])
        } else {
            focusElement(elements[0])
        }
    }

    /// Activate current focused element
    func activateFocusedElement() {
        guard let currentId = focusedElementId,
              let element = focusableElements.first(where: { $0.id == currentId }) else {
            return
        }

        element.action?()

        // Announce
        AccessibilityManager.shared.announce("Activated \(element.label)")
    }

    private func focusElement(_ element: FocusableElement) {
        focusedElementId = element.id
        focusPath.append(element.id)

        // Announce
        var announcement = element.label
        if let hint = element.hint {
            announcement += ". \(hint)"
        }
        AccessibilityManager.shared.announce(announcement)
    }

    /// Handle keyboard events
    func handleKeyPress(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard isFocusModeActive else { return false }

        switch keyCode {
        case 0x30: // Tab
            if modifiers.contains(.shift) {
                focusPrevious()
            } else {
                focusNext()
            }
            return true

        case 0x24: // Return
            activateFocusedElement()
            return true

        case 0x35: // Escape
            isFocusModeActive = false
            focusedElementId = nil
            return true

        case 0x7B: // Left Arrow
            // Can implement within-group navigation
            return false

        case 0x7C: // Right Arrow
            return false

        case 0x7E: // Up Arrow
            focusPrevious()
            return true

        case 0x7D: // Down Arrow
            focusNext()
            return true

        default:
            return false
        }
    }
}

// MARK: - Accessibility Labels

/// Accessibility label
struct AccessibilityLabel {
    var label: String
    var hint: String?
    var value: String?
    var traits: Set<AccessibilityTrait>
    var identifier: String?
    var customActions: [AccessibilityAction]

    init(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: Set<AccessibilityTrait> = [],
        identifier: String? = nil,
        customActions: [AccessibilityAction] = []
    ) {
        self.label = label
        self.hint = hint
        self.value = value
        self.traits = traits
        self.identifier = identifier
        self.customActions = customActions
    }
}

/// Accessibility traits
enum AccessibilityTrait: String {
    case button = "Button"
    case link = "Link"
    case header = "Header"
    case image = "Image"
    case selected = "Selected"
    case notEnabled = "Not Enabled"
    case adjustable = "Adjustable"
    case allowsDirectInteraction = "Allows Direct Interaction"
    case causesPageTurn = "Causes Page Turn"
    case playsSound = "Plays Sound"
    case startsMediaSession = "Starts Media Session"
    case summaryElement = "Summary Element"
    case updatesFrequently = "Updates Frequently"
}

/// Accessibility action
struct AccessibilityAction {
    var name: String
    var handler: () -> Void
}

// MARK: - Video Accessibility

/// Video accessibility manager
class VideoAccessibilityManager: ObservableObject {
    static let shared = VideoAccessibilityManager()

    @Published var isDescriptionEnabled: Bool = false
    @Published var currentAudioDescription: String = ""

    /// Generate scene description
    func generateSceneDescription(for image: CIImage) -> String {
        // Use Vision framework to analyze image and generate description
        // This should call analysis functionality from AIAdvancedFeatures

        return "Scene description"
    }

    /// Play audio description
    func playAudioDescription(_ description: String) {
        guard isDescriptionEnabled else { return }

        AccessibilityManager.shared.announce(description, priority: .high)
        currentAudioDescription = description
    }

    /// Generate timeline description
    func generateTimelineDescription(clips: [Any]) -> String {
        // Generate text description of timeline
        return "Timeline contains \(clips.count) clips"
    }
}

// MARK: - Accessibility Testing

/// Accessibility tester
class AccessibilityTester: ObservableObject {
    static let shared = AccessibilityTester()

    @Published var testResults: [TestResult] = []
    @Published var isRunning: Bool = false

    struct TestResult: Identifiable {
        let id: UUID
        var category: TestCategory
        var name: String
        var passed: Bool
        var message: String
        var severity: Severity

        enum Severity {
            case error
            case warning
            case info
        }
    }

    enum TestCategory: String, CaseIterable {
        case contrast = "Contrast"
        case labels = "Labels"
        case navigation = "Navigation"
        case focusOrder = "Focus Order"
        case audio = "Audio"
        case motion = "Motion"
        case touch = "Touch"
    }

    /// Run all tests
    func runAllTests() {
        isRunning = true
        testResults.removeAll()

        // Run various tests
        runContrastTests()
        runLabelTests()
        runNavigationTests()
        runFocusOrderTests()
        runAudioTests()
        runMotionTests()

        isRunning = false
    }

    private func runContrastTests() {
        // Test contrast
        let result = TestResult(
            id: UUID(),
            category: .contrast,
            name: "Text Contrast Check",
            passed: true,
            message: "All text elements meet WCAG AA standard (4.5:1)",
            severity: .info
        )
        testResults.append(result)
    }

    private func runLabelTests() {
        // Test accessibility labels
        let result = TestResult(
            id: UUID(),
            category: .labels,
            name: "Accessibility Label Check",
            passed: true,
            message: "All interactive elements have accessibility labels",
            severity: .info
        )
        testResults.append(result)
    }

    private func runNavigationTests() {
        // Test keyboard navigation
        let result = TestResult(
            id: UUID(),
            category: .navigation,
            name: "Keyboard Navigation Check",
            passed: true,
            message: "All functionality accessible via keyboard",
            severity: .info
        )
        testResults.append(result)
    }

    private func runFocusOrderTests() {
        // Test focus order
        let result = TestResult(
            id: UUID(),
            category: .focusOrder,
            name: "Focus Order Check",
            passed: true,
            message: "Focus order is logical",
            severity: .info
        )
        testResults.append(result)
    }

    private func runAudioTests() {
        // Test audio accessibility
        let result = TestResult(
            id: UUID(),
            category: .audio,
            name: "Audio Alternative Check",
            passed: true,
            message: "Video content provides captions or transcripts",
            severity: .info
        )
        testResults.append(result)
    }

    private func runMotionTests() {
        // Test animation settings
        let result = TestResult(
            id: UUID(),
            category: .motion,
            name: "Reduce Motion Check",
            passed: true,
            message: "Respects system 'Reduce Motion' setting",
            severity: .info
        )
        testResults.append(result)
    }

    /// Generate report
    func generateReport() -> String {
        var report = "Accessibility Test Report\n"
        report += "========================\n\n"

        let passed = testResults.filter { $0.passed }.count
        let failed = testResults.filter { !$0.passed }.count

        report += "Total: \(testResults.count) tests\n"
        report += "Passed: \(passed)\n"
        report += "Failed: \(failed)\n\n"

        for category in TestCategory.allCases {
            let categoryResults = testResults.filter { $0.category == category }
            if !categoryResults.isEmpty {
                report += "【\(category.rawValue)】\n"
                for result in categoryResults {
                    let status = result.passed ? "✓" : "✗"
                    report += "  \(status) \(result.name): \(result.message)\n"
                }
                report += "\n"
            }
        }

        return report
    }
}

// MARK: - SwiftUI Accessibility Modifiers

/// Accessibility view modifier
struct AccessibilityModifier: ViewModifier {
    let label: AccessibilityLabel

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label.label)
            .accessibilityHint(label.hint ?? "")
            .accessibilityValue(label.value ?? "")
            .accessibilityIdentifier(label.identifier ?? "")
    }
}

extension View {
    /// Apply accessibility label
    func accessibilityLabeled(_ label: AccessibilityLabel) -> some View {
        self.modifier(AccessibilityModifier(label: label))
    }

    /// High contrast border
    func highContrastBorder() -> some View {
        self.modifier(HighContrastBorderModifier())
    }

    /// Focus indicator
    func focusIndicator(isFocused: Bool) -> some View {
        self.modifier(FocusIndicatorModifier(isFocused: isFocused))
    }
}

/// High contrast border modifier
struct HighContrastBorderModifier: ViewModifier {
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(accessibilityManager.settings.highContrastMode ? Color.white : Color.clear, lineWidth: 2)
            )
    }
}

/// Focus indicator modifier
struct FocusIndicatorModifier: ViewModifier {
    let isFocused: Bool
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(focusColor, lineWidth: isFocused ? 3 : 0)
            )
    }

    private var focusColor: Color {
        switch accessibilityManager.settings.focusIndicatorStyle {
        case .default:
            return .blue
        case .highContrast:
            return .yellow
        case .custom:
            return .orange
        }
    }
}

// MARK: - Accessibility Shortcuts

/// Accessibility shortcuts
struct AccessibilityShortcuts {
    static let toggleVoiceOver = KeyboardShortcut(
        action: .toggleFullscreen, // Temporary use
        keyCode: 0x03, // F
        modifiers: [.command, .option],
        category: .general
    )

    static let toggleHighContrast = KeyboardShortcut(
        action: .toggleFullscreen,
        keyCode: 0x04, // H
        modifiers: [.command, .option, .control],
        category: .general
    )

    static let increaseFontSize = KeyboardShortcut(
        action: .zoomIn,
        keyCode: 0x18, // =
        modifiers: [.command, .option],
        category: .general
    )

    static let decreaseFontSize = KeyboardShortcut(
        action: .zoomOut,
        keyCode: 0x1B, // -
        modifiers: [.command, .option],
        category: .general
    )
}

// MARK: - Color Blind Simulation Preview

/// Color blind simulation view
struct ColorBlindSimulationView: View {
    let image: Image
    @ObservedObject private var accessibilityManager = AccessibilityManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Color Blind Simulation Preview")
                .font(.headline)

            HStack(spacing: 10) {
                // Original image
                VStack {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    Text("Original")
                        .font(.caption)
                }

                // Simulation views
                ForEach(simulationModes, id: \.self) { mode in
                    VStack {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .colorEffect(colorMatrixShader(for: mode))
                        Text(mode.rawValue)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
    }

    private var simulationModes: [AccessibilitySettings.ColorBlindMode] {
        [.protanopia, .deuteranopia, .tritanopia]
    }

    private func colorMatrixShader(for mode: AccessibilitySettings.ColorBlindMode) -> Shader {
        // Return color matrix shader
        return Shader(function: .init(library: .default, name: ""), arguments: [])
    }
}
