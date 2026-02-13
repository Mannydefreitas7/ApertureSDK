#if canImport(AVFoundation)
import Foundation
import AVFoundation

/// Represents a track in the timeline
@available(iOS 15.0, macOS 12.0, *)
public class TimelineTrack {
    public let id: UUID
    public let type: TrackType
    public var clips: [VideoAsset]
    
    public enum TrackType {
        case video
        case audio
        case overlay
    }
    
    public init(type: TrackType) {
        self.id = UUID()
        self.type = type
        self.clips = []
    }
    
    public func addClip(_ clip: VideoAsset) {
        clips.append(clip)
    }
    
    public func removeClip(_ clip: VideoAsset) {
        clips.removeAll { $0.id == clip.id }
    }
}

/// Timeline management for video projects
@available(iOS 15.0, macOS 12.0, *)
public class Timeline {
    public private(set) var tracks: [TimelineTrack]
    public var currentTime: CMTime
    
    public init() {
        self.tracks = []
        self.currentTime = .zero
    }
    
    /// Calculate total duration of the timeline
    public var totalDuration: CMTime {
        var maxDuration: CMTime = .zero
        
        for track in tracks {
            var trackDuration: CMTime = .zero
            for clip in track.clips {
                trackDuration = CMTimeAdd(trackDuration, clip.trimmedDuration)
            }
            if CMTimeCompare(trackDuration, maxDuration) > 0 {
                maxDuration = trackDuration
            }
        }
        
        return maxDuration
    }
    
    /// Add a new track to the timeline
    /// - Parameter type: The type of track to add
    /// - Returns: The newly created track
    @discardableResult
    public func addTrack(type: TimelineTrack.TrackType) -> TimelineTrack {
        let track = TimelineTrack(type: type)
        tracks.append(track)
        return track
    }
    
    /// Remove a track from the timeline
    /// - Parameter track: The track to remove
    public func removeTrack(_ track: TimelineTrack) {
        tracks.removeAll { $0.id == track.id }
    }
    
    /// Get the clip at a specific time
    /// - Parameter time: The time to query
    /// - Returns: The video asset at that time, if any
    public func getClip(at time: CMTime) -> VideoAsset? {
        for track in tracks {
            guard track.type == .video else { continue }
            
            var currentTime: CMTime = .zero
            for clip in track.clips {
                let clipDuration = clip.trimmedDuration
                let clipEndTime = CMTimeAdd(currentTime, clipDuration)
                
                if CMTimeCompare(time, currentTime) >= 0 && CMTimeCompare(time, clipEndTime) < 0 {
                    return clip
                }
                
                currentTime = clipEndTime
            }
        }
        
        return nil
    }
}
#endif
