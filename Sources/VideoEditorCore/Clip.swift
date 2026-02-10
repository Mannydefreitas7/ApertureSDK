import Foundation

/// Represents a clip on a track
public struct Clip: Codable, Identifiable, Sendable {
    public var id: UUID
    public var type: ClipType
    public var timeRange: ClipTimeRange
    public var sourceURL: URL?
    public var sourceAssetId: String?
    public var transform: ClipTransform
    public var opacity: Double
    public var volume: Double
    public var effects: [Effect]
    public var isMuted: Bool
    
    /// The type of clip
    public enum ClipType: String, Codable, Sendable {
        case video
        case audio
        case image
        case text
    }
    
    public init(
        id: UUID = UUID(),
        type: ClipType,
        timeRange: ClipTimeRange,
        sourceURL: URL? = nil,
        sourceAssetId: String? = nil,
        transform: ClipTransform = .identity,
        opacity: Double = 1.0,
        volume: Double = 1.0,
        effects: [Effect] = [],
        isMuted: Bool = false
    ) {
        self.id = id
        self.type = type
        self.timeRange = timeRange
        self.sourceURL = sourceURL
        self.sourceAssetId = sourceAssetId
        self.transform = transform
        self.opacity = opacity
        self.volume = volume
        self.effects = effects
        self.isMuted = isMuted
    }
    
    /// Trim the clip to new start/duration
    public mutating func trim(start: Double, duration: Double) {
        self.timeRange = ClipTimeRange(start: start, duration: duration)
    }
    
    /// Split the clip at a given time offset from clip start, returning two clips
    public func split(at offset: Double) -> (Clip, Clip)? {
        guard offset > 0 && offset < timeRange.duration else { return nil }
        
        var first = self
        first.id = UUID()
        first.timeRange = ClipTimeRange(start: timeRange.start, duration: offset)
        
        var second = self
        second.id = UUID()
        second.timeRange = ClipTimeRange(start: timeRange.start + offset, duration: timeRange.duration - offset)
        
        return (first, second)
    }
}
