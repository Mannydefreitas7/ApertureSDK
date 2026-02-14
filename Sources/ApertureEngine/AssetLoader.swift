#if canImport(AVFoundation)
import Foundation
import AVFoundation
import ApertureCore

/// Loads and manages AVFoundation assets from Core model data
public actor AssetLoader {
    
    private var cache: [URL: AVAsset] = [:]
    
    public init() {}
    
    /// Load an AVAsset from a URL
    public func loadAsset(from url: URL) async throws -> AVAsset {
        if let cached = cache[url] {
            return cached
        }
        
        let asset = AVURLAsset(url: url)
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw ApertureError.invalidAsset
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
    public func generateThumbnail(from url: URL, at time: Double) async throws -> CGImage {
        let asset = try await loadAsset(from: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        return try await withCheckedThrowingContinuation { continuation in
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: cmTime)]) { _, image, _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let image, result == .succeeded else {
                    continuation.resume(throwing: ApertureError.invalidAsset)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }
    
    /// Clear the asset cache
    public func clearCache() {
        cache.removeAll()
    }
}
#endif
