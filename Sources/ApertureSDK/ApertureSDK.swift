import Foundation
@_exported import VideoEditorCore
@_exported import VideoEditorEngine
@_exported import VideoEditorExport
@_exported import VideoEditorSwiftUI
@_exported import VideoEditorAssets

/// ApertureSDK - A powerful Swift Video Editor SDK for iOS and macOS
/// Provides comprehensive video editing capabilities including trimming, merging, effects, overlays, and export functionality.
///
/// This is the umbrella module that re-exports all sub-modules:
/// - `VideoEditorCore`: Pure Swift models + timeline logic (Codable, no AVFoundation)
/// - `VideoEditorEngine`: AVFoundation + CoreImage render pipeline
/// - `VideoEditorSwiftUI`: SwiftUI components + bindings
/// - `VideoEditorExport`: Export session + presets
/// - `VideoEditorAssets`: LUT loader, bundled resources
///
/// You can import individual sub-modules for finer-grained control, or import
/// `ApertureSDK` to get everything at once.
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
