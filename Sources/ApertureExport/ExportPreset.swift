import Foundation
import ApertureCore

/// Export codec type
public enum ExportCodec: String, Codable, Sendable {
    case h264
    case h265
}

/// Export preset configuration
public struct ExportPreset: Codable, Sendable {
    public var resolution: CanvasSize
    public var bitrate: Int
    public var fps: Double
    public var codec: ExportCodec
    public var shouldOptimizeForNetworkUse: Bool
    
    public init(
        resolution: CanvasSize,
        bitrate: Int,
        fps: Double = 30,
        codec: ExportCodec = .h264,
        shouldOptimizeForNetworkUse: Bool = true
    ) {
        self.resolution = resolution
        self.bitrate = bitrate
        self.fps = fps
        self.codec = codec
        self.shouldOptimizeForNetworkUse = shouldOptimizeForNetworkUse
    }
    
    // MARK: - Built-in Presets
    
    public static let hd720p = ExportPreset(
        resolution: .hd720p,
        bitrate: 5_000_000
    )
    
    public static let hd1080p = ExportPreset(
        resolution: .hd1080p,
        bitrate: 8_000_000
    )
    
    public static let hd4K = ExportPreset(
        resolution: .hd4K,
        bitrate: 20_000_000,
        codec: .h265
    )
    
    public static let instagram = ExportPreset(
        resolution: .square1080,
        bitrate: 5_000_000
    )
    
    public static let twitter = ExportPreset(
        resolution: .hd720p,
        bitrate: 5_000_000
    )
    
    public static let portrait = ExportPreset(
        resolution: .portrait1080x1920,
        bitrate: 8_000_000
    )
}
