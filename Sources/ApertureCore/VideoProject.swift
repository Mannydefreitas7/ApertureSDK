#if canImport(AVFoundation)
import Foundation
import AVFoundation

/// Represents a video editing project
public class VideoProject: Identifiable {
    public let id: UUID
    public var name: String
    public private(set) var assets: [VideoAsset]
    public let timeline: Timeline
    public var resolution: CGSize
    public var frameRate: Float
    
    /// Initialize a new video project
    /// - Parameters:
    ///   - name: The name of the project
    ///   - resolution: The output resolution (default: 1920x1080)
    ///   - frameRate: The output frame rate (default: 30)
    public init(name: String, resolution: CGSize = CGSize(width: 1920, height: 1080), frameRate: Float = 30) {
        self.id = UUID()
        self.name = name
        self.assets = []
        self.timeline = Timeline()
        self.resolution = resolution
        self.frameRate = frameRate
    }
    
    /// Add an asset to the project
    /// - Parameter asset: The video asset to add
    public func addAsset(_ asset: VideoAsset) {
        assets.append(asset)
        
        // Add to main video track
        if timeline.tracks.isEmpty {
            timeline.addTrack(type: .video)
        }
        
        if let videoTrack = timeline.tracks.first(where: { $0.type == .video }) {
            videoTrack.addClip(asset)
        }
    }
    
    /// Remove an asset from the project
    /// - Parameter asset: The video asset to remove
    public func removeAsset(_ asset: VideoAsset) {
        assets.removeAll { $0.id == asset.id }
        
        // Remove from all tracks
        for track in timeline.tracks {
            track.removeClip(asset)
        }
    }

    var instance: Self { get { self } }

    /// Reorder assets in the project
    /// - Parameters:
    ///   - fromIndex: The source index
    ///   - toIndex: The destination index
    public func reorderAssets(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex >= 0 && fromIndex < assets.count &&
              toIndex >= 0 && toIndex < assets.count else {
            return
        }
        
        let asset = assets.remove(at: fromIndex)
        assets.insert(asset, at: toIndex)
        
        // Update video track order
        if let videoTrack = timeline.tracks.first(where: { $0.type == .video }) {
            if fromIndex < videoTrack.clips.count && toIndex < videoTrack.clips.count {
                let clip = videoTrack.clips.remove(at: fromIndex)
                videoTrack.clips.insert(clip, at: toIndex)
            }
        }
    }
}
#endif
