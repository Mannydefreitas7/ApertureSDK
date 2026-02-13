import Foundation
import AVFoundation
import CoreImage
import CoreGraphics
import CoreText

// MARK: - 6. Subtitle Enhancement Module

// MARK: - Karaoke Subtitles


// MARK: - 3D Text



// Use Title3DRenderer for rendering (implemented in EffectsEnhanced)

// MARK: - Handwriting Animation

struct HandwritingAnimation: Identifiable, Codable {
    let id: UUID
    var text: String
    var font: String
    var fontSize: CGFloat
    var color: CodableColor
    var strokeWidth: CGFloat
    var duration: Double
    var style: HandwritingStyle

    init(
        id: UUID = UUID(),
        text: String,
        font: String = "Bradley Hand",
        fontSize: CGFloat = 48,
        color: CodableColor = CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
        strokeWidth: CGFloat = 2,
        duration: Double = 3.0,
        style: HandwritingStyle = .natural
    ) {
        self.id = id
        self.text = text
        self.font = font
        self.fontSize = fontSize
        self.color = color
        self.strokeWidth = strokeWidth
        self.duration = duration
        self.style = style
    }
}

enum HandwritingStyle: String, Codable, CaseIterable {
    case natural = "Natural"
    case neat = "Neat"
    case calligraphy = "Calligraphy"
    case childish = "Childish"
}


// MARK: - Danmaku Subtitles



enum DanmakuType: String, Codable, CaseIterable {
    case scroll = "Scroll"
    case top = "Top Fixed"
    case bottom = "Bottom Fixed"
}


// MARK: - Path Text


enum TextPathType: String, Codable, CaseIterable {
    case wave = "Wave"
    case circle = "Circle"
    case arc = "Arc"
    case spiral = "Spiral"
    case heart = "Heart"
    case custom = "Custom"
}


// MARK: - Subtitle Templates



#if canImport(UIKit)
import UIKit
#endif
