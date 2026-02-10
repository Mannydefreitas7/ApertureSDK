import Foundation

/// Configuration options for ApertureSDK
public struct Configuration {
    
    /// API key for authentication
    public var apiKey: String?
    
    /// Debug mode flag
    public var debugMode: Bool
    
    /// Timeout interval for network requests
    public var timeoutInterval: TimeInterval
    
    /// Creates a new configuration with default values
    public init(
        apiKey: String? = nil,
        debugMode: Bool = false,
        timeoutInterval: TimeInterval = 30
    ) {
        self.apiKey = apiKey
        self.debugMode = debugMode
        self.timeoutInterval = timeoutInterval
    }
    
    /// Validates the configuration
    /// Returns true if the configuration is valid, false otherwise
    public var isValid: Bool {
        // Validate timeout interval is positive
        guard timeoutInterval > 0 else {
            return false
        }
        
        // Additional validation can be added here as needed
        return true
    }
}
