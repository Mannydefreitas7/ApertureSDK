import Foundation
import AVFoundation

/// Represents a clip on a track
public struct Clip: Identifiable {
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
    /// Text content for text clips. Only used when `type == .text`.
    public var textContent: TextClipContent?
    /// Sub-timeline tracks for compound clips. Only used when `type == .compound`.
    public var subTimeline: [Track]?
    /// The type of clip
    public enum ClipType: String {
        case video
        case audio
        case image
        case text
        case compound
    }
}
