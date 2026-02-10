import Foundation

/// Represents a time range for a clip (in seconds).
///
/// `ClipTimeRange.start` is the **source media offset** — the point in the source file
/// where playback begins.  `ClipTimeRange.duration` is how long the clip plays.
///
/// Clips are **sequential on a track**: their timeline position is determined by their
/// order in `Track.clips`, not by `start`.  `Track.clip(at:)` walks the array and
/// accumulates durations to resolve a timeline time to a clip.
///
/// When building an `AVComposition`, `CompositionBuilder` uses `start` as the read
/// offset into the source asset and `duration` as the length to insert.
public struct ClipTimeRange: Codable, Equatable, Sendable {
    /// Offset into the source media in seconds
    public var start: Double
    /// Duration of the clip in seconds
    public var duration: Double
    
    public init(start: Double = 0, duration: Double = 0) {
        self.start = start
        self.duration = duration
    }
    
    /// End time in seconds
    public var end: Double {
        start + duration
    }
    
    /// Check if this range contains a specific time
    public func contains(_ time: Double) -> Bool {
        time >= start && time < end
    }
    
    /// Check if this range overlaps with another
    public func overlaps(with other: ClipTimeRange) -> Bool {
        start < other.end && end > other.start
    }
    
    /// A zero-length range at time 0
    public static let zero = ClipTimeRange(start: 0, duration: 0)
}
