#if canImport(AVFoundation)
import Foundation
import AVFoundation
import CoreImage
import ApertureCore

/// Describes what to render at a given time
public struct FrameRecipe {
    public var time: Double
    public var clips: [(clip: Clip, image: CIImage)]
    public var canvasSize: CanvasSize
    
    public init(time: Double, clips: [(clip: Clip, image: CIImage)], canvasSize: CanvasSize) {
        self.time = time
        self.clips = clips
        self.canvasSize = canvasSize
    }
}

/// Core rendering engine - renders frame recipes to pixel buffers
@available(iOS 15.0, macOS 12.0, *)
public class RenderEngine {
    
    private let ciContext: CIContext
    private let effectRenderer: EffectRenderer
    
    public init(ciContext: CIContext = CIContext()) {
        self.ciContext = ciContext
        self.effectRenderer = EffectRenderer(ciContext: ciContext)
    }
    
    /// Resolve what clips are active at a given time
    public func resolveFrameRecipe(project: Project, at time: Double) -> [Clip] {
        var activeClips: [Clip] = []
        
        for track in project.tracks {
            guard !track.isMuted else { continue }
            
            var currentTime: Double = 0
            for clip in track.clips {
                let clipEnd = currentTime + clip.timeRange.duration
                if time >= currentTime && time < clipEnd {
                    activeClips.append(clip)
                }
                currentTime = clipEnd
            }
        }
        
        return activeClips
    }
    
    /// Apply effects to a CIImage using the effect renderer
    public func applyEffects(_ effects: [Effect], to image: CIImage) -> CIImage {
        effectRenderer.apply(effects: effects, to: image)
    }
    
    /// Apply clip transform to a CIImage using anchor-point-based transformation.
    ///
    /// Transform order:
    /// 1. Move the image so that its anchor point is at the origin
    /// 2. Apply scale and rotation around the origin
    /// 3. Translate so that the anchor lies at the desired canvas position
    public func applyTransform(_ transform: ClipTransform, to image: CIImage, canvasSize: CanvasSize) -> CIImage {
        let originalExtent = image.extent
        
        // Compute anchor in image coordinates (anchorX/anchorY are normalized 0-1)
        let anchorPoint = CGPoint(
            x: originalExtent.origin.x + originalExtent.width * CGFloat(transform.anchorX),
            y: originalExtent.origin.y + originalExtent.height * CGFloat(transform.anchorY)
        )
        
        // Start by moving the anchor point to the origin
        var compositeTransform = CGAffineTransform(translationX: -anchorPoint.x, y: -anchorPoint.y)
        
        // Scale around the anchor/origin
        if transform.scaleX != 1.0 || transform.scaleY != 1.0 {
            compositeTransform = compositeTransform.scaledBy(
                x: CGFloat(transform.scaleX),
                y: CGFloat(transform.scaleY)
            )
        }
        
        // Rotate around the anchor/origin
        if transform.rotation != 0 {
            let radians = transform.rotation * .pi / 180
            compositeTransform = compositeTransform.rotated(by: CGFloat(radians))
        }
        
        // Translate so the anchor lies at the normalized position in the canvas
        let targetX = CGFloat(transform.positionX) * CGFloat(canvasSize.width)
        let targetY = CGFloat(transform.positionY) * CGFloat(canvasSize.height)
        compositeTransform = compositeTransform.translatedBy(x: targetX, y: targetY)
        
        return image.transformed(by: compositeTransform)
    }
    
    /// Composite multiple images together
    public func composite(images: [CIImage], canvasSize: CanvasSize) -> CIImage {
        let canvas = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height))
        
        var result = canvas
        for image in images {
            result = image.composited(over: result)
        }
        
        return result
    }
}
#endif
