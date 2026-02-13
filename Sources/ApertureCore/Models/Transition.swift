import Foundation
import AVFoundation

/// Represents a transition between two clips
public struct Transition: Codable, Identifiable, Sendable {
    public var id: UUID
    public var type: TransitionType
    public var duration: Double // seconds
    public var parameters: [String: Double]

    /// Application-side clip IDs (optional, for rendering)
    public var fromClipId: UUID?
    public var toClipId: UUID?

  
    public init(
        id: UUID = UUID(),
        type: TransitionType,
        duration: Double = 0.5,
        parameters: [String: Double] = [:],
        fromClipId: UUID? = nil,
        toClipId: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.duration = duration
        self.parameters = parameters
        self.fromClipId = fromClipId
        self.toClipId = toClipId
    }

    // MARK: - Factory Methods

    public static func crossDissolve(duration: Double = 0.5) -> Transition {
        Transition(type: .crossDissolve, duration: duration)
    }

    public static func slideLeft(duration: Double = 0.5) -> Transition {
        Transition(type: .slideLeft, duration: duration)
    }

    public static func slideRight(duration: Double = 0.5) -> Transition {
        Transition(type: .slideRight, duration: duration)
    }

    public static func wipeRight(duration: Double = 0.5) -> Transition {
        Transition(type: .wipeRight, duration: duration)
    }

    public static func wipeLeft(duration: Double = 0.5) -> Transition {
        Transition(type: .wipeLeft, duration: duration)
    }

    public static func fade(duration: Double = 0.5) -> Transition {
        Transition(type: .fade, duration: duration)
    }

    public static func zoom(duration: Double = 0.5) -> Transition {
        Transition(type: .zoom, duration: duration)
    }

    public static func dissolve(duration: Double = 0.5) -> Transition {
        Transition(type: .dissolve, duration: duration)
    }
}
