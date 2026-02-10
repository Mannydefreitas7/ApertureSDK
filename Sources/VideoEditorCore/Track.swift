import Foundation

/// Represents a track in the timeline
public struct Track: Codable, Identifiable, Sendable {
    public var id: UUID
    public var type: TrackType
    public var clips: [Clip]
    public var isMuted: Bool
    public var isLocked: Bool
    
    public enum TrackType: String, Codable, Sendable {
        case video
        case audio
        case overlay
    }
    
    public init(
        id: UUID = UUID(),
        type: TrackType,
        clips: [Clip] = [],
        isMuted: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.type = type
        self.clips = clips
        self.isMuted = isMuted
        self.isLocked = isLocked
    }
    
    /// Add a clip to the track
    public mutating func addClip(_ clip: Clip) {
        clips.append(clip)
    }
    
    /// Remove a clip by ID
    public mutating func removeClip(id: UUID) {
        clips.removeAll { $0.id == id }
    }
    
    /// Reorder clips
    public mutating func moveClip(from source: Int, to destination: Int) {
        guard source >= 0, source < clips.count,
              destination >= 0, destination < clips.count else { return }
        let clip = clips.remove(at: source)
        clips.insert(clip, at: destination)
    }
    
    /// Total duration of all clips in seconds
    public var totalDuration: Double {
        clips.reduce(0) { $0 + $1.timeRange.duration }
    }
    
    /// Get the clip at a specific time (seconds)
    public func clip(at time: Double) -> Clip? {
        var currentTime: Double = 0
        for clip in clips {
            let clipEnd = currentTime + clip.timeRange.duration
            if time >= currentTime && time < clipEnd {
                return clip
            }
            currentTime = clipEnd
        }
        return nil
    }
}
