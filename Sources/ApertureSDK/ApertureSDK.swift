import Foundation

/// ApertureSDK - A powerful Swift Video Editor SDK for iOS and macOS
/// Provides comprehensive video editing capabilities including trimming, merging, effects, overlays, and export functionality.
public final class ApertureSDK {
    
    /// Shared singleton instance
    public static let shared = ApertureSDK()
    
    /// Current configuration
    public private(set) var configuration: Configuration
    
    /// SDK version
    public static let version = "1.0.0"
    
    /// Private initializer for singleton
    private init() {
        self.configuration = Configuration()
    }
    
    /// Configure the SDK with custom settings
    /// - Parameter configuration: The configuration to use
    public func configure(with configuration: Configuration) {
        self.configuration = configuration
    }
    
    /// Initialize the SDK
    /// - Throws: ApertureError if initialization fails
    public func initialize() throws {
        guard configuration.isValid else {
            throw ApertureError.invalidConfiguration
        }
        // Initialization logic here
    }
}
