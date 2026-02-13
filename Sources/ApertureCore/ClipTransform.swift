import Foundation

/// Represents spatial transform for a clip
public struct ClipTransform {
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
}
