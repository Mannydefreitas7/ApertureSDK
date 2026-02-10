import Foundation

/// Represents a time range for a clip (in seconds)
public struct ClipTimeRange: Codable, Equatable, Sendable {
    /// Start time in seconds
    public var start: Double
    /// Duration in seconds
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
