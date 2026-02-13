import Foundation
import AVFoundation
import CoreGraphics

// MARK: - Keyframe Basics

enum AnimatableProperty: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    var displayName: String { rawValue }

    // Transform
    case positionX = "Position X"
    case positionY = "Position Y"
    case scale = "Scale"
    case scaleX = "Scale X"
    case scaleY = "Scale Y"
    case rotation = "Rotation"
    case anchorX = "Anchor X"
    case anchorY = "Anchor Y"
    case position = "Position"
    case anchorPoint = "Anchor Point"

    // Appearance
    case opacity = "Opacity"

    // Filter parameters
    case filterIntensity = "Filter Intensity"
    case brightness = "Brightness"
    case contrast = "Contrast"
    case saturation = "Saturation"

    // Blur
    case blurRadius = "Blur Radius"

    // Crop
    case cropLeft = "Crop Left"
    case cropRight = "Crop Right"
    case cropTop = "Crop Top"
    case cropBottom = "Crop Bottom"

    var defaultValue: CGFloat {
        switch self {
        case .positionX, .positionY, .position: return 0.5
        case .scale, .scaleX, .scaleY: return 1.0
        case .rotation: return 0
        case .anchorX, .anchorY, .anchorPoint: return 0.5
        case .opacity: return 1.0
        case .filterIntensity: return 1.0
        case .brightness: return 0
        case .contrast, .saturation: return 1.0
        case .blurRadius: return 0
        case .cropLeft, .cropRight, .cropTop, .cropBottom: return 0
        }
    }

    var range: ClosedRange<CGFloat> {
        switch self {
        case .positionX, .positionY, .position: return -1...2
        case .scale, .scaleX, .scaleY: return 0.01...10
        case .rotation: return -360...360
        case .anchorX, .anchorY, .anchorPoint: return 0...1
        case .opacity: return 0...1
        case .filterIntensity: return 0...2
        case .brightness: return -1...1
        case .contrast, .saturation: return 0...3
        case .blurRadius: return 0...100
        case .cropLeft, .cropRight, .cropTop, .cropBottom: return 0...0.5
        }
    }
}

struct Keyframe<T: Interpolatable>: Identifiable, Equatable where T: Equatable {
    let id: UUID
    var time: CMTime
    var value: T
    var easing: EasingFunction

    init(
        id: UUID = UUID(),
        time: CMTime,
        value: T,
        easing: EasingFunction = .linear
    ) {
        self.id = id
        self.time = time
        self.value = value
        self.easing = easing
    }

    static func == (lhs: Keyframe<T>, rhs: Keyframe<T>) -> Bool {
        lhs.id == rhs.id
    }
}

enum EasingFunction: String, CaseIterable, Codable {
    case linear = "Linear"
    case easeIn = "Ease In"
    case easeOut = "Ease Out"
    case easeInOut = "Ease In Out"
    case easeInQuad = "Ease In Quad"
    case easeOutQuad = "Ease Out Quad"
    case easeInOutQuad = "Ease In Out Quad"
    case easeInCubic = "Ease In Cubic"
    case easeOutCubic = "Ease Out Cubic"
    case easeInOutCubic = "Ease In Out Cubic"
    case easeInElastic = "Elastic In"
    case easeOutElastic = "Elastic Out"
    case easeInBounce = "Bounce In"
    case easeOutBounce = "Bounce Out"
    case spring = "Spring"
    case bounce = "Bounce"

    func apply(_ t: CGFloat) -> CGFloat {
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return 1 - (1 - t) * (1 - t)
        case .easeInOut:
            if t < 0.5 { return 2 * t * t } else { return 1 - pow(-2 * t + 2, 2) / 2 }
        case .spring:
            let damping: CGFloat = 0.5
            let stiffness: CGFloat = 8.0
            return 1 - exp(-stiffness * t) * cos(10 * .pi * t) * (1 - damping)
        case .bounce:
            if t < 4/11.0 { return (121 * t * t)/16.0 }
            else if t < 8/11.0 { return (363/40.0 * t * t) - (99/10.0 * t) + 17/5.0 }
            else if t < 9/10.0 { return (4356/361.0 * t * t) - (35442/1805.0 * t) + 16061/1805.0 }
            else { return (54/5.0 * t * t) - (513/25.0 * t) + 268/25.0 }
        default:
            return 0
        }
    }

    func value(at t: CGFloat) -> CGFloat {
        let t = max(0, min(1, t))

        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t * t
        case .easeOut:
            return 1 - pow(1 - t, 3)
        case .easeInOut:
            return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        case .easeInQuad:
            return t * t
        case .easeOutQuad:
            return 1 - (1 - t) * (1 - t)
        case .easeInOutQuad:
            return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        case .easeInCubic:
            return t * t * t
        case .easeOutCubic:
            return 1 - pow(1 - t, 3)
        case .easeInOutCubic:
            return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        case .easeInElastic:
            if t == 0 { return 0 }
            if t == 1 { return 1 }
            return -pow(2, 10 * t - 10) * sin((t * 10 - 10.75) * (2 * .pi) / 3)
        case .easeOutElastic:
            if t == 0 { return 0 }
            if t == 1 { return 1 }
            return pow(2, -10 * t) * sin((t * 10 - 0.75) * (2 * .pi) / 3) + 1
        case .easeInBounce:
            return 1 - EasingFunction.easeOutBounce.value(at: 1 - t)
        case .easeOutBounce:
            if t < 1 / 2.75 {
                return 7.5625 * t * t
            } else if t < 2 / 2.75 {
                let t = t - 1.5 / 2.75
                return 7.5625 * t * t + 0.75
            } else if t < 2.5 / 2.75 {
                let t = t - 2.25 / 2.75
                return 7.5625 * t * t + 0.9375
            } else {
                let t = t - 2.625 / 2.75
                return 7.5625 * t * t + 0.984375
            }
        case .spring:
            let decay: CGFloat = 0.5
            let frequency: CGFloat = 3
            return 1 - exp(-decay * t * 10) * cos(frequency * t * .pi * 2)
        default:
            return 0
        }
    }

    var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .easeIn: return "Ease In"
        case .easeOut: return "Ease Out"
        case .easeInOut: return "Ease In-Out"
        case .spring: return "Spring"
        case .bounce: return "Bounce"
        case .easeInQuad: return "Ease In Quad"
        default:
            return "temp"
        }
    }

    static var defaultCases: [EasingFunction] { [.linear, .easeIn, .easeOut, .easeInOut, .spring, .bounce] }
}

protocol Interpolatable {
    static func interpolate(from: Self, to: Self, progress: CGFloat) -> Self
}

extension CGFloat: Interpolatable {
    static func interpolate(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}

extension CGPoint: Interpolatable {
    static func interpolate(from: CGPoint, to: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat.interpolate(from: from.x, to: to.x, progress: progress),
            y: CGFloat.interpolate(from: from.y, to: to.y, progress: progress)
        )
    }
}

extension CGSize: Interpolatable {
    static func interpolate(from: CGSize, to: CGSize, progress: CGFloat) -> CGSize {
        CGSize(
            width: CGFloat.interpolate(from: from.width, to: to.width, progress: progress),
            height: CGFloat.interpolate(from: from.height, to: to.height, progress: progress)
        )
    }
}

// MARK: - Keyframe Track

class KeyframeTrack<T: Interpolatable & Equatable>: ObservableObject {
    @Published var keyframes: [Keyframe<T>] = []
    let property: AnimatableProperty

    init(property: AnimatableProperty) {
        self.property = property
    }

    func addKeyframe(at time: CMTime, value: T, easing: EasingFunction = .linear) {
        if let index = keyframes.firstIndex(where: { CMTimeCompare($0.time, time) == 0 }) {
            keyframes[index].value = value
            keyframes[index].easing = easing
        } else {
            let keyframe = Keyframe(time: time, value: value, easing: easing)
            keyframes.append(keyframe)
            sortKeyframes()
        }
    }

    func removeKeyframe(id: UUID) {
        keyframes.removeAll { $0.id == id }
    }

    func removeKeyframe(at time: CMTime) {
        keyframes.removeAll { CMTimeCompare($0.time, time) == 0 }
    }

    func sortKeyframes() {
        keyframes.sort { CMTimeCompare($0.time, $1.time) < 0 }
    }

    func value(at time: CMTime) -> T? {
        guard !keyframes.isEmpty else { return nil }

        var prevKeyframe: Keyframe<T>?
        var nextKeyframe: Keyframe<T>?

        for keyframe in keyframes {
            if CMTimeCompare(keyframe.time, time) <= 0 {
                prevKeyframe = keyframe
            } else {
                nextKeyframe = keyframe
                break
            }
        }

        if prevKeyframe == nil {
            return nextKeyframe?.value
        }
        if nextKeyframe == nil {
            return prevKeyframe?.value
        }

        guard let prev = prevKeyframe, let next = nextKeyframe else {
            return nil
        }

        let totalDuration = CMTimeGetSeconds(CMTimeSubtract(next.time, prev.time))
        let currentOffset = CMTimeGetSeconds(CMTimeSubtract(time, prev.time))
        let linearProgress = CGFloat(currentOffset / totalDuration)
        let easedProgress = next.easing.value(at: linearProgress)

        return T.interpolate(from: prev.value, to: next.value, progress: easedProgress)
    }

    func hasKeyframe(at time: CMTime, tolerance: CMTime = CMTime(value: 1, timescale: 30)) -> Bool {
        keyframes.contains { keyframe in
            let diff = CMTimeAbsoluteValue(CMTimeSubtract(keyframe.time, time))
            return CMTimeCompare(diff, tolerance) <= 0
        }
    }
}

// MARK: - Animation Group

class ClipAnimationGroup: ObservableObject {
    let clipId: UUID

    @Published var positionX = KeyframeTrack<CGFloat>(property: .positionX)
    @Published var positionY = KeyframeTrack<CGFloat>(property: .positionY)
    @Published var scale = KeyframeTrack<CGFloat>(property: .scale)
    @Published var rotation = KeyframeTrack<CGFloat>(property: .rotation)
    @Published var opacity = KeyframeTrack<CGFloat>(property: .opacity)

    init(clipId: UUID) {
        self.clipId = clipId
    }

    func transform(at time: CMTime, videoSize: CGSize) -> CGAffineTransform {
        let x = positionX.value(at: time) ?? 0.5
        let y = positionY.value(at: time) ?? 0.5
        let s = scale.value(at: time) ?? 1.0
        let r = rotation.value(at: time) ?? 0

        var transform = CGAffineTransform.identity

        transform = transform.translatedBy(
            x: x * videoSize.width,
            y: y * videoSize.height
        )

        transform = transform.rotated(by: r * .pi / 180)

        transform = transform.scaledBy(x: s, y: s)

        transform = transform.translatedBy(
            x: -videoSize.width / 2,
            y: -videoSize.height / 2
        )

        return transform
    }

    func opacityValue(at time: CMTime) -> CGFloat {
        opacity.value(at: time) ?? 1.0
    }

    var hasAnimations: Bool {
        !positionX.keyframes.isEmpty ||
        !positionY.keyframes.isEmpty ||
        !scale.keyframes.isEmpty ||
        !rotation.keyframes.isEmpty ||
        !opacity.keyframes.isEmpty
    }

    var allTracks: [any KeyframeTrackProtocol] {
        [positionX, positionY, scale, rotation, opacity]
    }
}

protocol KeyframeTrackProtocol {
    var property: AnimatableProperty { get }
    var keyframeCount: Int { get }
}

extension KeyframeTrack: KeyframeTrackProtocol {
    var keyframeCount: Int { keyframes.count }
}

// MARK: - Preset Animation

enum PresetAnimation: String, CaseIterable {
    case fadeIn = "Fade In"
    case fadeOut = "Fade Out"
    case slideInLeft = "Slide In Left"
    case slideInRight = "Slide In Right"
    case slideInTop = "Slide In Top"
    case slideInBottom = "Slide In Bottom"
    case slideOutLeft = "Slide Out Left"
    case slideOutRight = "Slide Out Right"
    case zoomIn = "Zoom In"
    case zoomOut = "Zoom Out"
    case rotateIn = "Rotate In"
    case bounceIn = "Bounce In"
    case flipIn = "Flip In"

    var icon: String {
        switch self {
        case .fadeIn: return "circle.righthalf.filled"
        case .fadeOut: return "circle.lefthalf.filled"
        case .slideInLeft: return "arrow.right"
        case .slideInRight: return "arrow.left"
        case .slideInTop: return "arrow.down"
        case .slideInBottom: return "arrow.up"
        case .slideOutLeft: return "arrow.left"
        case .slideOutRight: return "arrow.right"
        case .zoomIn: return "plus.magnifyingglass"
        case .zoomOut: return "minus.magnifyingglass"
        case .rotateIn: return "arrow.clockwise"
        case .bounceIn: return "arrow.up.and.down"
        case .flipIn: return "arrow.left.and.right.righttriangle.left.righttriangle.right"
        }
    }

    func apply(
        to group: ClipAnimationGroup,
        startTime: CMTime,
        duration: CMTime,
        isEntrance: Bool = true
    ) {
        let endTime = CMTimeAdd(startTime, duration)

        switch self {
        case .fadeIn:
            group.opacity.addKeyframe(at: startTime, value: 0, easing: .easeOut)
            group.opacity.addKeyframe(at: endTime, value: 1, easing: .linear)

        case .fadeOut:
            group.opacity.addKeyframe(at: startTime, value: 1, easing: .easeIn)
            group.opacity.addKeyframe(at: endTime, value: 0, easing: .linear)

        case .slideInLeft:
            group.positionX.addKeyframe(at: startTime, value: -0.5, easing: .easeOut)
            group.positionX.addKeyframe(at: endTime, value: 0.5, easing: .linear)

        case .slideInRight:
            group.positionX.addKeyframe(at: startTime, value: 1.5, easing: .easeOut)
            group.positionX.addKeyframe(at: endTime, value: 0.5, easing: .linear)

        case .slideInTop:
            group.positionY.addKeyframe(at: startTime, value: 1.5, easing: .easeOut)
            group.positionY.addKeyframe(at: endTime, value: 0.5, easing: .linear)

        case .slideInBottom:
            group.positionY.addKeyframe(at: startTime, value: -0.5, easing: .easeOut)
            group.positionY.addKeyframe(at: endTime, value: 0.5, easing: .linear)

        case .slideOutLeft:
            group.positionX.addKeyframe(at: startTime, value: 0.5, easing: .easeIn)
            group.positionX.addKeyframe(at: endTime, value: -0.5, easing: .linear)

        case .slideOutRight:
            group.positionX.addKeyframe(at: startTime, value: 0.5, easing: .easeIn)
            group.positionX.addKeyframe(at: endTime, value: 1.5, easing: .linear)

        case .zoomIn:
            group.scale.addKeyframe(at: startTime, value: 0.1, easing: .easeOutElastic)
            group.scale.addKeyframe(at: endTime, value: 1.0, easing: .linear)
            group.opacity.addKeyframe(at: startTime, value: 0, easing: .easeOut)
            group.opacity.addKeyframe(at: endTime, value: 1, easing: .linear)

        case .zoomOut:
            group.scale.addKeyframe(at: startTime, value: 1.0, easing: .easeIn)
            group.scale.addKeyframe(at: endTime, value: 0.1, easing: .linear)
            group.opacity.addKeyframe(at: startTime, value: 1, easing: .easeIn)
            group.opacity.addKeyframe(at: endTime, value: 0, easing: .linear)

        case .rotateIn:
            group.rotation.addKeyframe(at: startTime, value: -180, easing: .easeOut)
            group.rotation.addKeyframe(at: endTime, value: 0, easing: .linear)
            group.scale.addKeyframe(at: startTime, value: 0.5, easing: .easeOut)
            group.scale.addKeyframe(at: endTime, value: 1.0, easing: .linear)
            group.opacity.addKeyframe(at: startTime, value: 0, easing: .easeOut)
            group.opacity.addKeyframe(at: endTime, value: 1, easing: .linear)

        case .bounceIn:
            group.scale.addKeyframe(at: startTime, value: 0.3, easing: .easeOutBounce)
            group.scale.addKeyframe(at: endTime, value: 1.0, easing: .linear)
            group.opacity.addKeyframe(at: startTime, value: 0, easing: .linear)
            group.opacity.addKeyframe(at: CMTimeAdd(startTime, CMTimeMultiplyByFloat64(duration, multiplier: 0.1)), value: 1, easing: .linear)

        case .flipIn:
            group.scale.addKeyframe(at: startTime, value: 0.01, easing: .easeOut)
            group.scale.addKeyframe(at: endTime, value: 1.0, easing: .linear)
            group.rotation.addKeyframe(at: startTime, value: 90, easing: .easeOut)
            group.rotation.addKeyframe(at: endTime, value: 0, easing: .linear)
        }
    }
}

// MARK: - Motion Path

struct MotionPath: Identifiable, Equatable {
    let id: UUID
    var points: [PathPoint]
    var isClosed: Bool

    init(id: UUID = UUID(), points: [PathPoint] = [], isClosed: Bool = false) {
        self.id = id
        self.points = points
        self.isClosed = isClosed
    }

    struct PathPoint: Identifiable, Equatable {
        let id: UUID
        var position: CGPoint
        var controlPoint1: CGPoint?
        var controlPoint2: CGPoint?

        init(
            id: UUID = UUID(),
            position: CGPoint,
            controlPoint1: CGPoint? = nil,
            controlPoint2: CGPoint? = nil
        ) {
            self.id = id
            self.position = position
            self.controlPoint1 = controlPoint1
            self.controlPoint2 = controlPoint2
        }
    }

    func position(at progress: CGFloat) -> CGPoint? {
        guard points.count >= 2 else { return points.first?.position }

        let totalSegments = CGFloat(points.count - (isClosed ? 0 : 1))
        let segmentProgress = progress * totalSegments
        let segmentIndex = Int(segmentProgress)
        let localProgress = segmentProgress - CGFloat(segmentIndex)

        let startIndex = segmentIndex % points.count
        let endIndex = (segmentIndex + 1) % points.count

        let start = points[startIndex]
        let end = points[endIndex]

        if let cp1 = start.controlPoint2, let cp2 = end.controlPoint1 {
            return cubicBezier(
                p0: start.position,
                p1: cp1,
                p2: cp2,
                p3: end.position,
                t: localProgress
            )
        } else {
            return CGPoint.interpolate(from: start.position, to: end.position, progress: localProgress)
        }
    }

    private func cubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt
        let t2 = t * t
        let t3 = t2 * t

        let x = mt3 * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t3 * p3.x
        let y = mt3 * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t3 * p3.y

        return CGPoint(x: x, y: y)
    }
}
