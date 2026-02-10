#if canImport(AVFoundation)
import Foundation
import CoreImage
import CoreMedia
import CoreGraphics

/// Protocol for video overlays
public protocol OverlayProtocol {
    var id: UUID { get }
    var startTime: CMTime { get set }
    var duration: CMTime { get set }
    var position: CGPoint { get set }
    func render(at time: CMTime, size: CGSize) -> CIImage?
}
#endif
