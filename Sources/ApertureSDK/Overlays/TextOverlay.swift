#if canImport(AVFoundation)
import Foundation
import CoreImage
import CoreMedia
import CoreGraphics
import CoreText

#if canImport(UIKit)
import UIKit
public typealias PlatformFont = UIFont
public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias PlatformFont = NSFont
public typealias PlatformColor = NSColor
#endif

/// Text overlay for video
@available(iOS 15.0, macOS 12.0, *)
public class TextOverlay: OverlayProtocol {
    public let id: UUID
    public var startTime: CMTime
    public var duration: CMTime
    public var position: CGPoint
    
    public var text: String
    public var font: PlatformFont
    public var fontSize: CGFloat
    public var color: PlatformColor
    public var backgroundColor: PlatformColor?
    public var alignment: TextAlignment
    public var animation: TextAnimation?
    
    public enum TextAlignment {
        case left
        case center
        case right
    }
    
    public enum TextAnimation {
        case fadeIn
        case fadeOut
        case fadeInOut
    }
    
    /// Initialize a text overlay
    /// - Parameters:
    ///   - text: The text to display
    ///   - font: The font to use
    ///   - color: The text color
    ///   - startTime: When the overlay appears
    ///   - duration: How long the overlay is visible
    ///   - position: The position of the overlay (normalized 0-1)
    public init(
        text: String,
        font: PlatformFont = PlatformFont.systemFont(ofSize: 48),
        color: PlatformColor = .white,
        startTime: CMTime,
        duration: CMTime,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.id = UUID()
        self.text = text
        self.font = font
        self.fontSize = font.pointSize
        self.color = color
        self.startTime = startTime
        self.duration = duration
        self.position = position
        self.alignment = .center
    }
    
    public func render(at time: CMTime, size: CGSize) -> CIImage? {
        // Check if overlay should be visible at this time
        let overlayEndTime = CMTimeAdd(startTime, duration)
        guard CMTimeCompare(time, startTime) >= 0 && CMTimeCompare(time, overlayEndTime) <= 0 else {
            return nil
        }
        
        // Calculate alpha based on animation
        var alpha: CGFloat = 1.0
        if let animation = animation {
            let elapsed = CMTimeGetSeconds(CMTimeSubtract(time, startTime))
            let totalDuration = CMTimeGetSeconds(duration)
            
            switch animation {
            case .fadeIn:
                alpha = min(1.0, CGFloat(elapsed / totalDuration))
            case .fadeOut:
                alpha = max(0.0, CGFloat(1.0 - elapsed / totalDuration))
            case .fadeInOut:
                let halfDuration = totalDuration / 2
                if elapsed < halfDuration {
                    alpha = min(1.0, CGFloat(elapsed / halfDuration))
                } else {
                    alpha = max(0.0, CGFloat(1.0 - (elapsed - halfDuration) / halfDuration))
                }
            }
        }
        
        // Render text to image (simplified implementation)
        // In a real implementation, you would use Core Graphics to render the text
        return nil
    }
}
#endif
