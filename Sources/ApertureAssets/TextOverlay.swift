import Foundation
import AVFoundation
import CoreGraphics
import CoreText
import SwiftUI
#if canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
#elseif canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
#endif

// MARK: - CMTime Codable Extension

extension CMTime: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case value
        case timescale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Int64.self, forKey: .value)
        let timescale = try container.decode(Int32.self, forKey: .timescale)
        self.init(value: value, timescale: timescale)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(timescale, forKey: .timescale)
    }
}

extension CMTimeRange: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case start
        case duration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let start = try container.decode(CMTime.self, forKey: .start)
        let duration = try container.decode(CMTime.self, forKey: .duration)
        self.init(start: start, duration: duration)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(start, forKey: .start)
        try container.encode(duration, forKey: .duration)
    }
}

/// Unified text overlay model for video editing
public struct UnifiedTextOverlay: Identifiable, Equatable {
    public let id: UUID
    public var text: String
    public var style: TextStyle
    public var position: TextPosition
    public var animation: TextAnimation

    /// Time range on the timeline
    public var timeRange: CMTimeRange

    public init(
        id: UUID = UUID(),
        text: String = "Text",
        style: TextStyle = TextStyle(),
        position: TextPosition = .center,
        animation: TextAnimation = .none,
        timeRange: CMTimeRange
    ) {
        self.id = id
        self.text = text
        self.style = style
        self.position = position
        self.animation = animation
        self.timeRange = timeRange
    }

    public static func == (lhs: UnifiedTextOverlay, rhs: UnifiedTextOverlay) -> Bool {
        lhs.id == rhs.id
    }
}

/// Text style configuration
public struct TextStyle: Equatable, Codable {
    public var fontName: String = "PingFang SC"
    public var fontSize: CGFloat = 48
    public var fontWeight: FontWeight = .medium
    public var textColor: CodableColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 1)
    public var backgroundColor: CodableColor? = nil
    public var strokeColor: CodableColor? = nil
    public var strokeWidth: CGFloat = 0
    public var shadowColor: CodableColor? = CodableColor(red: 0, green: 0, blue: 0, alpha: 0.5)
    public var shadowOffset: CGSize = CGSize(width: 2, height: 2)
    public var shadowBlur: CGFloat = 4
    public var letterSpacing: CGFloat = 0
    public var lineSpacing: CGFloat = 0
    public var alignment: TextAlignment = .center

    public init(
        fontName: String = "PingFang SC",
        fontSize: CGFloat = 48,
        fontWeight: FontWeight = .medium,
        textColor: CodableColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
        backgroundColor: CodableColor? = nil,
        strokeColor: CodableColor? = nil,
        strokeWidth: CGFloat = 0,
        shadowColor: CodableColor? = CodableColor(red: 0, green: 0, blue: 0, alpha: 0.5),
        shadowOffset: CGSize = CGSize(width: 2, height: 2),
        shadowBlur: CGFloat = 4,
        letterSpacing: CGFloat = 0,
        lineSpacing: CGFloat = 0,
        alignment: TextAlignment = .center
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.shadowColor = shadowColor
        self.shadowOffset = shadowOffset
        self.shadowBlur = shadowBlur
        self.letterSpacing = letterSpacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
    }

    /// Get platform font
    public var font: PlatformFont {
        let weight: PlatformFont.Weight
        switch fontWeight {
        case .ultraLight: weight = .ultraLight
        case .thin: weight = .thin
        case .light: weight = .light
        case .regular: weight = .regular
        case .medium: weight = .medium
        case .semibold: weight = .semibold
        case .bold: weight = .bold
        case .heavy: weight = .heavy
        case .black: weight = .black
        }

        return PlatformFont.systemFont(ofSize: fontSize, weight: weight)
    }
}

/// Font weight
public enum FontWeight: String, CaseIterable, Codable {
    case ultraLight = "Ultra Light"
    case thin = "Thin"
    case light = "Light"
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    case heavy = "Heavy"
    case black = "Black"
}

/// Text alignment
public enum TextAlignment: String, CaseIterable, Codable {
    case left = "Left"
    case center = "Center"
    case right = "Right"
}

/// Text position
public enum TextPosition: String, CaseIterable, Codable {
    case topLeft = "Top Left"
    case topCenter = "Top Center"
    case topRight = "Top Right"
    case centerLeft = "Center Left"
    case center = "Center"
    case centerRight = "Center Right"
    case bottomLeft = "Bottom Left"
    case bottomCenter = "Bottom Center"
    case bottomRight = "Bottom Right"
    case custom = "Custom"

    /// Custom position (only used when position == .custom)
    public var customPoint: CGPoint? { nil }

    /// Get normalized position in video (0-1)
    public func normalizedPosition(in size: CGSize, textSize: CGSize) -> CGPoint {
        let margin: CGFloat = 0.05 // 5% 边距

        switch self {
        case .topLeft:
            return CGPoint(x: margin, y: 1 - margin - textSize.height / size.height)
        case .topCenter:
            return CGPoint(x: 0.5 - textSize.width / size.width / 2, y: 1 - margin - textSize.height / size.height)
        case .topRight:
            return CGPoint(x: 1 - margin - textSize.width / size.width, y: 1 - margin - textSize.height / size.height)
        case .centerLeft:
            return CGPoint(x: margin, y: 0.5 - textSize.height / size.height / 2)
        case .center:
            return CGPoint(x: 0.5 - textSize.width / size.width / 2, y: 0.5 - textSize.height / size.height / 2)
        case .centerRight:
            return CGPoint(x: 1 - margin - textSize.width / size.width, y: 0.5 - textSize.height / size.height / 2)
        case .bottomLeft:
            return CGPoint(x: margin, y: margin)
        case .bottomCenter:
            return CGPoint(x: 0.5 - textSize.width / size.width / 2, y: margin)
        case .bottomRight:
            return CGPoint(x: 1 - margin - textSize.width / size.width, y: margin)
        case .custom:
            return CGPoint(x: 0.5, y: 0.5)
        }
    }
}

/// Text animation
public enum TextAnimation: String, CaseIterable, Codable {
    case none = "None"
    case fadeIn = "Fade In"
    case fadeOut = "Fade Out"
    case fadeInOut = "Fade In/Out"
    case slideUp = "Slide Up"
    case slideDown = "Slide Down"
    case slideLeft = "Slide Left"
    case slideRight = "Slide Right"
    case slideFromBottom = "Slide From Bottom"
    case typewriter = "Typewriter"
    case scale = "Scale"
    case bounce = "Bounce"
    case pop = "Pop"

    public var icon: String {
        switch self {
        case .none: return "xmark"
        case .fadeIn: return "circle.righthalf.filled"
        case .fadeOut: return "circle.lefthalf.filled"
        case .fadeInOut: return "circle.fill"
        case .slideUp: return "arrow.up"
        case .slideDown: return "arrow.down"
        case .slideLeft: return "arrow.left"
        case .slideRight: return "arrow.right"
        case .slideFromBottom: return "arrow.up.square"
        case .typewriter: return "keyboard"
        case .scale: return "arrow.up.left.and.arrow.down.right"
        case .bounce: return "arrow.up.and.down"
        case .pop: return "sparkles"
        }
    }
}

/// 可编码的颜色
/// Codable color wrapper for cross-platform compatibility
public struct CodableColor: Equatable, Codable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat

    public init(_ color: PlatformColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(AppKit)
        let converted = color.usingColorSpace(.sRGB) ?? color
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        self.red = r
        self.green = g
        self.blue = b
        self.alpha = a
    }

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var platformColor: PlatformColor {
        PlatformColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

/// 文字图层生成器
class TextLayerGenerator {

    /// 创建文字 CALayer
    static func createTextLayer(
        for overlay: TextOverlay,
        videoSize: CGSize
    ) -> CATextLayer {
        let textLayer = CATextLayer()

        // 设置文字
        textLayer.string = overlay.text
        textLayer.font = overlay.style.font
        textLayer.fontSize = overlay.style.fontSize
        textLayer.foregroundColor = overlay.style.textColor.cgColor

        // 对齐方式
        switch overlay.style.alignment {
        case .left: textLayer.alignmentMode = .left
        case .center: textLayer.alignmentMode = .center
        case .right: textLayer.alignmentMode = .right
        }

        // 计算文字大小
        let textSize = calculateTextSize(overlay.text, style: overlay.style, maxWidth: videoSize.width * 0.9)
        textLayer.frame = CGRect(origin: .zero, size: textSize)

        // 设置位置
        let normalizedPos = overlay.position.normalizedPosition(in: videoSize, textSize: textSize)
        textLayer.position = CGPoint(
            x: normalizedPos.x * videoSize.width + textSize.width / 2,
            y: normalizedPos.y * videoSize.height + textSize.height / 2
        )

        // 背景
        if let bgColor = overlay.style.backgroundColor {
            textLayer.backgroundColor = bgColor.cgColor
            textLayer.cornerRadius = 4
        }

        // 阴影
        if let shadowColor = overlay.style.shadowColor {
            textLayer.shadowColor = shadowColor.cgColor
            textLayer.shadowOffset = overlay.style.shadowOffset
            textLayer.shadowRadius = overlay.style.shadowBlur
            textLayer.shadowOpacity = 1.0
        }

        // 渲染质量
        textLayer.contentsScale = 2.0
        textLayer.isWrapped = true
        textLayer.truncationMode = .end

        return textLayer
    }

    /// 计算文字尺寸
    static func calculateTextSize(_ text: String, style: TextStyle, maxWidth: CGFloat) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.font
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        return CGSize(
            width: ceil(boundingRect.width) + 20,
            height: ceil(boundingRect.height) + 10
        )
    }

    /// 添加动画到文字图层
    static func addAnimation(
        to layer: CATextLayer,
        animation: TextAnimation,
        duration: CFTimeInterval,
        timeRange: CMTimeRange
    ) {
        let startTime = CMTimeGetSeconds(timeRange.start)
        let endTime = CMTimeGetSeconds(timeRange.end)
        let clipDuration = endTime - startTime
        let animDuration = min(0.5, clipDuration / 2) // 动画时长最多0.5秒

        switch animation {
        case .none:
            break

        case .fadeIn:
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.duration = animDuration
            fadeIn.beginTime = startTime
            fadeIn.fillMode = .forwards
            fadeIn.isRemovedOnCompletion = false
            layer.add(fadeIn, forKey: "fadeIn")

        case .fadeOut:
            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.duration = animDuration
            fadeOut.beginTime = endTime - animDuration
            fadeOut.fillMode = .forwards
            fadeOut.isRemovedOnCompletion = false
            layer.add(fadeOut, forKey: "fadeOut")

        case .fadeInOut:
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.duration = animDuration
            fadeIn.beginTime = startTime
            layer.add(fadeIn, forKey: "fadeIn")

            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.duration = animDuration
            fadeOut.beginTime = endTime - animDuration
            fadeOut.fillMode = .forwards
            fadeOut.isRemovedOnCompletion = false
            layer.add(fadeOut, forKey: "fadeOut")

        case .slideUp:
            let slideUp = CABasicAnimation(keyPath: "position.y")
            slideUp.fromValue = layer.position.y - 100
            slideUp.toValue = layer.position.y
            slideUp.duration = animDuration
            slideUp.beginTime = startTime
            slideUp.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(slideUp, forKey: "slideUp")

        case .slideDown:
            let slideDown = CABasicAnimation(keyPath: "position.y")
            slideDown.fromValue = layer.position.y + 100
            slideDown.toValue = layer.position.y
            slideDown.duration = animDuration
            slideDown.beginTime = startTime
            slideDown.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(slideDown, forKey: "slideDown")

        case .slideLeft:
            let slide = CABasicAnimation(keyPath: "position.x")
            slide.fromValue = layer.position.x + 100
            slide.toValue = layer.position.x
            slide.duration = animDuration
            slide.beginTime = startTime
            slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(slide, forKey: "slideLeft")

        case .slideRight:
            let slide = CABasicAnimation(keyPath: "position.x")
            slide.fromValue = layer.position.x - 100
            slide.toValue = layer.position.x
            slide.duration = animDuration
            slide.beginTime = startTime
            slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(slide, forKey: "slideRight")

        case .scale:
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.5
            scale.toValue = 1.0
            scale.duration = animDuration
            scale.beginTime = startTime
            scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(scale, forKey: "scale")

        case .bounce:
            let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
            bounce.values = [0.5, 1.2, 0.9, 1.05, 1.0]
            bounce.keyTimes = [0, 0.4, 0.6, 0.8, 1.0]
            bounce.duration = animDuration * 1.5
            bounce.beginTime = startTime
            layer.add(bounce, forKey: "bounce")

        case .typewriter:
            // 打字机效果需要特殊处理
            break

        case .slideFromBottom:
            let slide = CABasicAnimation(keyPath: "position.y")
            slide.fromValue = layer.position.y + 200
            slide.toValue = layer.position.y
            slide.duration = animDuration
            slide.beginTime = startTime
            slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(slide, forKey: "slideFromBottom")

        case .pop:
            let pop = CAKeyframeAnimation(keyPath: "transform.scale")
            pop.values = [0, 1.2, 1.0]
            pop.keyTimes = [0, 0.6, 1.0]
            pop.duration = animDuration
            pop.beginTime = startTime
            pop.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(pop, forKey: "pop")
        }
    }
}

/// 字幕模型（与 TextOverlay 类似，但用于字幕轨道）
struct Subtitle: Identifiable, Equatable {
    let id: UUID
    var text: String
    var timeRange: CMTimeRange
    var style: TextStyle

    init(
        id: UUID = UUID(),
        text: String,
        timeRange: CMTimeRange,
        style: TextStyle = TextStyle()
    ) {
        self.id = id
        self.text = text
        self.timeRange = timeRange
        self.style = style
        self.style.fontSize = 24 // 字幕默认字号
        self.style.shadowColor = CodableColor(.black)
    }

    static func == (lhs: Subtitle, rhs: Subtitle) -> Bool {
        lhs.id == rhs.id
    }
}

/// SRT 字幕解析器
class SRTParser {

    /// 解析 SRT 文件
    static func parse(from url: URL) throws -> [Subtitle] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parse(content: content)
    }

    /// 解析 SRT 内容
    static func parse(content: String) -> [Subtitle] {
        var subtitles: [Subtitle] = []
        let blocks = content.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard lines.count >= 3 else { continue }

            // 解析时间码
            let timeLine = lines[1]
            guard let timeRange = parseTimeCode(timeLine) else { continue }

            // 获取文字内容
            let text = lines[2...].joined(separator: "\n")

            let subtitle = Subtitle(
                text: text,
                timeRange: timeRange
            )
            subtitles.append(subtitle)
        }

        return subtitles
    }

    /// 解析时间码行 "00:00:01,000 --> 00:00:04,000"
    private static func parseTimeCode(_ line: String) -> CMTimeRange? {
        let parts = line.components(separatedBy: " --> ")
        guard parts.count == 2,
              let startTime = parseTime(parts[0]),
              let endTime = parseTime(parts[1]) else {
            return nil
        }

        return CMTimeRange(start: startTime, end: endTime)
    }

    /// 解析时间 "00:00:01,000"
    private static func parseTime(_ string: String) -> CMTime? {
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.components(separatedBy: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else {
            return nil
        }

        let totalSeconds = hours * 3600 + minutes * 60 + seconds
        return CMTime(seconds: totalSeconds, preferredTimescale: 1000)
    }

    /// 导出为 SRT 格式
    static func export(subtitles: [Subtitle]) -> String {
        var output = ""

        for (index, subtitle) in subtitles.enumerated() {
            let startTime = formatTime(subtitle.timeRange.start)
            let endTime = formatTime(subtitle.timeRange.end)

            output += "\(index + 1)\n"
            output += "\(startTime) --> \(endTime)\n"
            output += "\(subtitle.text)\n\n"
        }

        return output
    }

    /// 格式化时间为 SRT 格式
    private static func formatTime(_ time: CMTime) -> String {
        let totalSeconds = CMTimeGetSeconds(time)
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        let milliseconds = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 1000)

        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
}
