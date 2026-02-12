import Foundation

/// Manages bundled resources for the VideoEditor SDK
public class ResourceManager {
    
    /// The shared resource manager
    public static let shared = ResourceManager()
    
    private init() {}
    
    /// Get the bundle for VideoEditorAssets module resources
    public var resourceBundle: Bundle {
        Bundle.module
    }
    
    /// Get URL for a bundled resource
    /// - Parameters:
    ///   - name: Resource file name
    ///   - ext: Resource file extension
    /// - Returns: URL to the resource, or nil if not found
    public func resourceURL(named name: String, withExtension ext: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext)
    }
    
    /// List available LUT files in the bundle
    public func availableLUTs() -> [String] {
        guard let urls = Bundle.module.urls(forResourcesWithExtension: "cube", subdirectory: nil) else {
            return []
        }
        return urls.compactMap { url -> String? in
            guard let filename = url.lastPathComponent else { return nil }
            if let dotRange = filename.range(of: ".", options: .backwards) {
                return String(filename[filename.startIndex..<dotRange.lowerBound])
            }
            return filename
        }
    }
}
