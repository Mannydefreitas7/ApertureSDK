#if canImport(AVFoundation)
import Foundation
import AVFoundation
import ApertureCore

/// Loads and manages AVFoundation assets from Core model data
@available(iOS 15.0, macOS 12.0, *)
public actor AssetLoader {
    
    private var cache: [URL: AVAsset] = [:]
    
    public init() {}
    
    /// Load an AVAsset from a URL
    public func loadAsset(from url: URL) async throws -> AVAsset {
        if let cached = cache[url] {
            return cached
        }
        
        let asset = AVAsset(url: url)
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw VideoEditorError.invalidAsset
        }
        cache[url] = asset
        return asset
    }
    
    /// Get the duration of an asset in seconds
    public func duration(of url: URL) async throws -> Double {
        let asset = try await loadAsset(from: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
    
    /// Generate a thumbnail from a video asset
    @available(iOS 16, macOS 13, *)
    public func generateThumbnail(from url: URL, at time: Double) async throws -> CGImage {
        let asset = try await loadAsset(from: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        let cgImage = try await imageGenerator.image(at: cmTime).image
        return cgImage
    }
    
    /// Clear the asset cache
    public func clearCache() {
        cache.removeAll()
    }
}
#endif
