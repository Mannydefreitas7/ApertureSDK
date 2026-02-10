import Foundation

/// Represents spatial transform for a clip
public struct ClipTransform: Codable, Equatable, Sendable {
    /// X position (normalized 0-1, center = 0.5)
    public var positionX: Double
    /// Y position (normalized 0-1, center = 0.5)
    public var positionY: Double
    /// Scale factor (1.0 = 100%)
    public var scaleX: Double
    /// Scale factor (1.0 = 100%)
    public var scaleY: Double
    /// Rotation in degrees
    public var rotation: Double
    /// Anchor point X (normalized 0-1)
    public var anchorX: Double
    /// Anchor point Y (normalized 0-1)
    public var anchorY: Double
    
    public init(
        positionX: Double = 0.5,
        positionY: Double = 0.5,
        scaleX: Double = 1.0,
        scaleY: Double = 1.0,
        rotation: Double = 0,
        anchorX: Double = 0.5,
        anchorY: Double = 0.5
    ) {
        self.positionX = positionX
        self.positionY = positionY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotation = rotation
        self.anchorX = anchorX
        self.anchorY = anchorY
    }
    
    /// Identity transform (centered, no rotation, no scale)
    public static let identity = ClipTransform()
}
