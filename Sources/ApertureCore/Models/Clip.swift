import Foundation
import AVFoundation

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
    /// Text content for text clips. Only used when `type == .text`.
    public var textContent: TextClipContent?
    /// Sub-timeline tracks for compound clips. Only used when `type == .compound`.
    public var subTimeline: [Track]?

    /// The type of clip
    public enum ClipType: String, Codable, Sendable {
        case video
        case audio
        case image
        case text
        case compound
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
        isMuted: Bool = false,
        textContent: TextClipContent? = nil,
        subTimeline: [Track]? = nil
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
        self.textContent = textContent
        self.subTimeline = subTimeline
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

    /// Total duration of the sub-timeline (for compound clips)
    public var subTimelineDuration: Double {
        subTimeline?.map { $0.totalDuration }.max() ?? 0
    }

    /// Create a compound clip from a list of clips
    ///
    /// Groups the provided clips into a single compound clip whose `subTimeline`
    /// contains one track holding the clips. The compound clip's `timeRange`
    /// duration equals the sum of the grouped clips' durations.
    ///
    /// - Parameters:
    ///   - clips: Clips to group.
    ///   - trackType: Track type for the inner track (default `.video`).
    /// - Returns: A compound clip, or `nil` if `clips` is empty.
    public static func makeCompound(
        from clips: [Clip],
        trackType: Track.TrackType = .video
    ) -> Clip? {
        guard !clips.isEmpty else { return nil }

        let totalDuration = clips.reduce(0) { $0 + $1.timeRange.duration }
        let innerTrack = Track(type: trackType, clips: clips)

        return Clip(
            type: .compound,
            timeRange: ClipTimeRange(start: 0, duration: totalDuration),
            subTimeline: [innerTrack]
        )
    }
}
