import Foundation

/// Errors that can occur in VideoEditorCore
public enum ApertureError: Error, Equatable, Sendable {
    /// The configuration is invalid
    case invalidConfiguration
    /// A network error occurred
    case networkError(String)
    /// The operation is not supported
    case unsupportedOperation
    /// A general error with a message
    case general(String)
    /// The asset is invalid or cannot be loaded
    case invalidAsset
    /// Export operation failed
    case exportFailed(String)
    /// The format is not supported
    case unsupportedFormat
    /// Insufficient permissions
    case insufficientPermissions
    /// Invalid time range
    case invalidTimeRange
    /// Project serialization failed
    case serializationFailed(String)
    /// Render failed
    case renderFailed(String)
    /// Operation was cancelled
    case cancelled
}

extension ApertureError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid configuration"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unsupportedOperation:
            return "Operation not supported"
        case .general(let message):
            return message
        case .invalidAsset:
            return "Invalid asset or cannot be loaded"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .unsupportedFormat:
            return "Unsupported format"
        case .insufficientPermissions:
            return "Insufficient permissions to access the resource"
        case .invalidTimeRange:
            return "Invalid time range specified"
        case .serializationFailed(let message):
            return "Serialization failed: \(message)"
        case .renderFailed(let message):
            return "Render failed: \(message)"
        case .cancelled:
            return "Operation was cancelled"
        }
    }
}
