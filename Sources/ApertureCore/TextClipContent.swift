import Foundation

/// Text content for text clips
public struct TextClipContent: Codable, Sendable {
    public var text: String
    public var fontName: String
    public var fontSize: Double
    public var colorHex: String
    public var backgroundColorHex: String?
    public var alignment: TextClipAlignment
    public var animation: TextClipAnimation?
    
    public enum TextClipAlignment: String, Codable, Sendable {
        case left, center, right
    }
    
    public enum TextClipAnimation: String, Codable, Sendable {
        case fadeIn, fadeOut, fadeInOut
    }
    
    public init(
        text: String,
        fontName: String = "Helvetica",
        fontSize: Double = 48,
        colorHex: String = "#FFFFFF",
        backgroundColorHex: String? = nil,
        alignment: TextClipAlignment = .center,
        animation: TextClipAnimation? = nil
    ) {
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.colorHex = colorHex
        self.backgroundColorHex = backgroundColorHex
        self.alignment = alignment
        self.animation = animation
    }
}
