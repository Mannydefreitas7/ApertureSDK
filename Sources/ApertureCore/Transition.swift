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

    public enum TransitionType: String, Codable, Sendable, CaseIterable {
        case none
        case crossDissolve
        case fade
        case slideLeft
        case slideRight
        case slideUp
        case slideDown
        case wipeLeft
        case wipeRight
        case wipeUp
        case wipeDown
        case zoom
        case blur
        case dissolve

        public var displayName: String {
            switch self {
            case .none: return "None"
            case .crossDissolve: return "Cross Dissolve"
            case .fade: return "Fade"
            case .slideLeft: return "Slide Left"
            case .slideRight: return "Slide Right"
            case .slideUp: return "Slide Up"
            case .slideDown: return "Slide Down"
            case .wipeLeft: return "Wipe Left"
            case .wipeRight: return "Wipe Right"
            case .wipeUp: return "Wipe Up"
            case .wipeDown: return "Wipe Down"
            case .zoom: return "Zoom"
            case .blur: return "Blur"
            case .dissolve: return "Dissolve"
            }
        }

        public var icon: String {
            switch self {
            case .none: return "xmark"
            case .crossDissolve, .dissolve: return "square.on.square"
            case .fade: return "circle.lefthalf.filled"
            case .wipeLeft: return "arrow.left.square"
            case .wipeRight: return "arrow.right.square"
            case .wipeUp: return "arrow.up.square"
            case .wipeDown: return "arrow.down.square"
            case .slideLeft: return "rectangle.lefthalf.inset.filled.arrow.left"
            case .slideRight: return "rectangle.righthalf.inset.filled.arrow.right"
            case .slideUp: return "arrow.up.square"
            case .slideDown: return "arrow.down.square"
            case .zoom: return "arrow.up.left.and.arrow.down.right"
            case .blur: return "aqi.medium"
            }
        }
    }

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
