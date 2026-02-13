import Foundation
import AVFoundation

/// Represents a track in the timeline
public struct Track: Identifiable {
    public var id: UUID
    public var type: TrackType
    public var clips: [Clip]
    public var isMuted: Bool
    public var name: String
    public var isLocked: Bool
    public var isVisible: Bool = true
    public var volume: Float = 1.0

    /// Total duration (in seconds) based on the last clip's end time
    public var duration: Double {
        clips.map { $0.timeRange.start + $0.timeRange.duration }.max() ?? 0
    }
}
