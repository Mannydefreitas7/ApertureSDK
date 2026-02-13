import Foundation

/// Represents the canvas size for a project
public struct CanvasSize: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double
    
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
    
    // MARK: - Presets
    public static let hd720p = CanvasSize(width: 1280, height: 720)
    public static let hd1080p = CanvasSize(width: 1920, height: 1080)
    public static let hd4K = CanvasSize(width: 3840, height: 2160)
    public static let square1080 = CanvasSize(width: 1080, height: 1080)
    public static let portrait1080x1920 = CanvasSize(width: 1080, height: 1920)
    
    /// Aspect ratio (width / height)
    public var aspectRatio: Double {
        guard height > 0 else { return 0 }
        return width / height
    }
}
