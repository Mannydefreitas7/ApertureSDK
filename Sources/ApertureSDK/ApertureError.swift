import Foundation

/// Errors that can occur when using ApertureSDK
public enum ApertureError: Error, Equatable {
    /// The SDK configuration is invalid
    case invalidConfiguration
    
    /// A network error occurred
    case networkError(Error)
    
    /// The operation is not supported
    case unsupportedOperation
    
    /// A general error with a message
    case general(String)
    
    /// The video asset is invalid or cannot be loaded
    case invalidAsset
    
    /// Export operation failed
    case exportFailed
    
    /// The video format is not supported
    case unsupportedFormat
    
    /// Insufficient permissions to access the resource
    case insufficientPermissions
    
    /// The specified time range is invalid
    case invalidTimeRange
    
    public static func == (lhs: ApertureError, rhs: ApertureError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidConfiguration, .invalidConfiguration),
             (.unsupportedOperation, .unsupportedOperation),
             (.invalidAsset, .invalidAsset),
             (.exportFailed, .exportFailed),
             (.unsupportedFormat, .unsupportedFormat),
             (.insufficientPermissions, .insufficientPermissions),
             (.invalidTimeRange, .invalidTimeRange):
            return true
        case let (.networkError(lhsError), .networkError(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case let (.general(lhsMsg), .general(rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
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
        case .invalidAsset:
            return "Invalid video asset or cannot be loaded"
        case .exportFailed:
            return "Video export operation failed"
        case .unsupportedFormat:
            return "Unsupported video format"
        case .insufficientPermissions:
            return "Insufficient permissions to access the resource"
        case .invalidTimeRange:
            return "Invalid time range specified"
        }
    }
}
