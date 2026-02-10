#if canImport(AVFoundation)
import Foundation
import AVFoundation
import CoreMedia

/// Transition effect between video clips
@available(iOS 15.0, macOS 12.0, *)
public struct TransitionEffect: EffectProtocol {
    public let id: UUID
    public let name: String
    public let type: TransitionType
    public let duration: CMTime
    
    public enum TransitionType {
        case fade
        case crossfade
        case wipeLeft
        case wipeRight
        case wipeUp
        case wipeDown
        case dissolve
    }
    
    /// Initialize a transition effect
    /// - Parameters:
    ///   - type: The type of transition
    ///   - duration: The duration of the transition
    public init(type: TransitionType, duration: CMTime) {
        self.id = UUID()
        self.type = type
        self.duration = duration
        
        switch type {
        case .fade:
            self.name = "Fade"
        case .crossfade:
            self.name = "Crossfade"
        case .wipeLeft:
            self.name = "Wipe Left"
        case .wipeRight:
            self.name = "Wipe Right"
        case .wipeUp:
            self.name = "Wipe Up"
        case .wipeDown:
            self.name = "Wipe Down"
        case .dissolve:
            self.name = "Dissolve"
        }
    }
    
    public func apply(to composition: AVMutableVideoComposition) -> AVMutableVideoComposition {
        // Apply transition to video composition
        // This is a simplified implementation
        return composition
    }
    
    // MARK: - Convenience Initializers
    
    /// Fade in effect
    /// - Parameter duration: The duration of the fade
    /// - Returns: A fade in transition
    public static func fadeIn(duration: CMTime) -> TransitionEffect {
        return TransitionEffect(type: .fade, duration: duration)
    }
    
    /// Fade out effect
    /// - Parameter duration: The duration of the fade
    /// - Returns: A fade out transition
    public static func fadeOut(duration: CMTime) -> TransitionEffect {
        return TransitionEffect(type: .fade, duration: duration)
    }
    
    /// Crossfade effect
    /// - Parameter duration: The duration of the crossfade
    /// - Returns: A crossfade transition
    public static func crossfade(duration: CMTime) -> TransitionEffect {
        return TransitionEffect(type: .crossfade, duration: duration)
    }
}
#endif
