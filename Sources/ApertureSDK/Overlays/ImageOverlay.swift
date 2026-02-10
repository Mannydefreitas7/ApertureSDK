#if canImport(AVFoundation)
import Foundation
import CoreImage
import CoreMedia
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Image overlay for video
@available(iOS 15.0, macOS 12.0, *)
public class ImageOverlay: OverlayProtocol {
    public let id: UUID
    public var startTime: CMTime
    public var duration: CMTime
    public var position: CGPoint
    
    public var image: CIImage
    public var scale: CGFloat
    public var rotation: CGFloat
    public var alpha: CGFloat
    public var animation: ImageAnimation?
    
    public enum ImageAnimation {
        case fadeIn
        case fadeOut
        case fadeInOut
    }
    
    /// Initialize an image overlay
    /// - Parameters:
    ///   - image: The image to display
    ///   - startTime: When the overlay appears
    ///   - duration: How long the overlay is visible
    ///   - position: The position of the overlay (normalized 0-1)
    ///   - scale: The scale of the image (default: 1.0)
    public init(
        image: CIImage,
        startTime: CMTime,
        duration: CMTime,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        scale: CGFloat = 1.0
    ) {
        self.id = UUID()
        self.image = image
        self.startTime = startTime
        self.duration = duration
        self.position = position
        self.scale = scale
        self.rotation = 0.0
        self.alpha = 1.0
    }
    
    /// Render the image overlay at a specific time
    /// - Parameters:
    ///   - time: The current playback time
    ///   - size: The video frame size
    /// - Returns: A CIImage of the rendered overlay, or nil if not visible
    /// - Note: This returns the transformed image. For complete implementation,
    ///         integrate with AVVideoComposition's custom compositor to composite
    ///         the image onto the video frame.
    public func render(at time: CMTime, size: CGSize) -> CIImage? {
        // Check if overlay should be visible at this time
        let overlayEndTime = CMTimeAdd(startTime, duration)
        guard CMTimeCompare(time, startTime) >= 0 && CMTimeCompare(time, overlayEndTime) <= 0 else {
            return nil
        }
        
        // Calculate alpha based on animation
        var effectiveAlpha = alpha
        if let animation = animation {
            let elapsed = CMTimeGetSeconds(CMTimeSubtract(time, startTime))
            let totalDuration = CMTimeGetSeconds(duration)
            
            switch animation {
            case .fadeIn:
                effectiveAlpha *= min(1.0, CGFloat(elapsed / totalDuration))
            case .fadeOut:
                effectiveAlpha *= max(0.0, CGFloat(1.0 - elapsed / totalDuration))
            case .fadeInOut:
                let halfDuration = totalDuration / 2
                if elapsed < halfDuration {
                    effectiveAlpha *= min(1.0, CGFloat(elapsed / halfDuration))
                } else {
                    effectiveAlpha *= max(0.0, CGFloat(1.0 - (elapsed - halfDuration) / halfDuration))
                }
            }
        }
        
        // Apply transformations
        var transformedImage = image
        
        // Scale
        if scale != 1.0 {
            let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
            transformedImage = transformedImage.transformed(by: scaleTransform)
        }
        
        // Rotation
        if rotation != 0.0 {
            let rotationTransform = CGAffineTransform(rotationAngle: rotation)
            transformedImage = transformedImage.transformed(by: rotationTransform)
        }
        
        return transformedImage
    }
}
#endif
