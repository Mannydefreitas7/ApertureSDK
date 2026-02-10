import Foundation

/// Errors that can occur when using ApertureSDK
public enum ApertureError: Error {
    /// The SDK configuration is invalid
    case invalidConfiguration
    
    /// A network error occurred
    case networkError(Error)
    
    /// The operation is not supported
    case unsupportedOperation
    
    /// A general error with a message
    case general(String)
}

extension ApertureError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid SDK configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unsupportedOperation:
            return "Operation not supported"
        case .general(let message):
            return message
        }
    }
}
