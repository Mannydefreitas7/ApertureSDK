#if canImport(AVFoundation)
import Foundation
import AVFoundation
import CoreImage

/// Represents a video asset in the editing project
@available(iOS 15.0, macOS 12.0, *)
public class VideoAsset: Identifiable {
    public let id: UUID
    public let url: URL
    public private(set) var duration: CMTime
    public var startTime: CMTime
    public var endTime: CMTime
    public var volume: Float
    
    private var effects: [any EffectProtocol] = []
    private var overlays: [any OverlayProtocol] = []
    private let asset: AVAsset
    
    /// Initialize a video asset from a URL
    /// - Parameter url: The URL of the video file
    /// - Throws: ApertureError if the asset cannot be loaded
    public init(url: URL) async throws {
        self.id = UUID()
        self.url = url
        self.asset = AVURLAsset(url: url)
        self.volume = 1.0
        
        // Load asset properties
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw ApertureError.invalidAsset
        }
        
        let duration = try await asset.load(.duration)
        self.duration = duration
        self.startTime = .zero
        self.endTime = duration
    }
    
    /// Get the underlying AVAsset
    public var avAsset: AVAsset {
        return asset
    }
    
    /// Trim the video to a specific time range
    /// - Parameters:
    ///   - start: The start time
    ///   - end: The end time
    /// - Throws: ApertureError if the time range is invalid
    public func trim(start: CMTime, end: CMTime) throws {
        guard start >= .zero && end <= duration && start < end else {
            throw ApertureError.invalidTimeRange
        }
        self.startTime = start
        self.endTime = end
    }
    
    /// Apply an effect to the video
    /// - Parameter effect: The effect to apply
    public func applyEffect(_ effect: any EffectProtocol) {
        effects.append(effect)
    }
    
    /// Add an overlay to the video
    /// - Parameter overlay: The overlay to add
    public func addOverlay(_ overlay: any OverlayProtocol) {
        overlays.append(overlay)
    }
    
    /// Get all applied effects
    public func getEffects() -> [any EffectProtocol] {
        return effects
    }
    
    /// Get all overlays
    public func getOverlays() -> [any OverlayProtocol] {
        return overlays
    }
    
    /// Get the trimmed duration
    public var trimmedDuration: CMTime {
        return CMTimeSubtract(endTime, startTime)
    }
    
    /// Generate a thumbnail at a specific time
    /// - Parameter time: The time to generate the thumbnail
    /// - Returns: A CGImage thumbnail
    @available(iOS 16, macOS 13, *)
    public func generateThumbnail(at time: CMTime) async throws -> CGImage {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        let cgImage = try await imageGenerator.image(at: time).image
        return cgImage
    }
}
#endif
