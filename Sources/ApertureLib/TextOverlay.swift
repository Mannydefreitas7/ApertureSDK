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



/// Unified text overlay model for video editing
public struct TextOverlay: Identifiable {
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
        style: TextStyle,
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

}


/// Font weight
public enum FontWeight: String, CaseIterable {
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
public enum TextAlignment: String, CaseIterable {
    case left = "Left"
    case center = "Center"
    case right = "Right"
}

/// Text position
public enum TextPosition: String, CaseIterable {
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

struct Subtitle: Identifiable {
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
        self.style.fontSize = 24
        self.style.textColor = .black
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
