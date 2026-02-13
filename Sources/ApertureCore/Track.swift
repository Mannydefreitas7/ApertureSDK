import Foundation
import AVFoundation

/// Represents a track in the timeline
public struct Track: Codable, Identifiable, Sendable {
    public var id: UUID
    public var type: TrackType
    public var clips: [Clip]
    public var isMuted: Bool
    public var name: String
    public var isLocked: Bool
    public var isVisible: Bool = true
    public var volume: Float = 1.0

    public enum TrackType: String, Codable, Sendable {
        case video
        case audio
        case overlay
        case subtitle
        case effect
    }

    /// Total duration (in seconds) based on the last clip's end time
    public var duration: Double {
        clips.map { $0.timeRange.start + $0.timeRange.duration }.max() ?? 0
    }

    public static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }

    public init(
        id: UUID = UUID(),
        name: String = "",
        type: TrackType,
        clips: [Clip] = [],
        isMuted: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.clips = clips
        self.isMuted = isMuted
        self.isLocked = isLocked
    }
}
