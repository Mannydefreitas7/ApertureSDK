import Foundation

/// Represents a transition between two clips
public struct Transition: Codable, Identifiable, Sendable {
    public var id: UUID
    public var type: TransitionType
    public var duration: Double // seconds
    public var parameters: [String: Double]
    
    public enum TransitionType: String, Codable, Sendable {
        case crossDissolve
        case slideLeft
        case slideRight
        case slideUp
        case slideDown
        case wipeLeft
        case wipeRight
        case wipeUp
        case wipeDown
        case fade
    }
    
    public init(
        id: UUID = UUID(),
        type: TransitionType,
        duration: Double = 0.5,
        parameters: [String: Double] = [:]
    ) {
        self.id = id
        self.type = type
        self.duration = duration
        self.parameters = parameters
    }
    
    // MARK: - Factory Methods
    
    public static func crossDissolve(duration: Double = 0.5) -> Transition {
        Transition(type: .crossDissolve, duration: duration)
    }
    
    public static func slideLeft(duration: Double = 0.5) -> Transition {
        Transition(type: .slideLeft, duration: duration)
    }
    
    public static func wipeRight(duration: Double = 0.5) -> Transition {
        Transition(type: .wipeRight, duration: duration)
    }
    
    public static func fade(duration: Double = 0.5) -> Transition {
        Transition(type: .fade, duration: duration)
    }
}
