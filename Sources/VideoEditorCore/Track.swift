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
    
    /// Group clips with the given IDs into a compound clip.
    ///
    /// The selected clips are removed from the track and replaced (at the
    /// position of the first selected clip) by a single compound clip whose
    /// `subTimeline` contains the grouped clips in their original order.
    ///
    /// - Parameter clipIDs: IDs of clips to group.
    /// - Returns: The newly created compound clip, or `nil` if fewer than
    ///   two matching clips are found.
    @discardableResult
    public mutating func groupClips(ids clipIDs: Set<UUID>) -> Clip? {
        let selected = clips.filter { clipIDs.contains($0.id) }
        guard selected.count >= 2 else { return nil }
        
        guard let compound = Clip.makeCompound(from: selected, trackType: type) else {
            return nil
        }
        
        // Find insertion index (position of first selected clip)
        guard let insertionIndex = clips.firstIndex(where: { clipIDs.contains($0.id) }) else {
            return nil
        }
        
        // Remove selected clips and insert compound clip
        clips.removeAll { clipIDs.contains($0.id) }
        clips.insert(compound, at: min(insertionIndex, clips.count))
        
        return compound
    }
    
    /// Ungroup a compound clip, replacing it with its inner clips.
    ///
    /// - Parameter id: The ID of the compound clip to ungroup.
    /// - Returns: The clips that were inside the compound clip, or `nil` if
    ///   the clip was not found or is not a compound clip.
    @discardableResult
    public mutating func ungroupCompoundClip(id: UUID) -> [Clip]? {
        guard let index = clips.firstIndex(where: { $0.id == id }),
              clips[index].type == .compound,
              let innerTracks = clips[index].subTimeline else {
            return nil
        }
        
        let innerClips = innerTracks.flatMap { $0.clips }
        clips.remove(at: index)
        clips.insert(contentsOf: innerClips, at: min(index, clips.count))
        
        return innerClips
    }
}
