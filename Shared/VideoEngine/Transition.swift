import Foundation
import AVFoundation
import CoreImage

/// 转场效果模型
struct Transition: Identifiable, Equatable {
    let id: UUID
    var type: TransitionType
    var duration: CMTime

    /// 应用转场的片段ID（转场在此片段结尾）
    var fromClipId: UUID

    /// 转场到的片段ID（转场在此片段开头）
    var toClipId: UUID

    init(
        id: UUID = UUID(),
        type: TransitionType = .crossDissolve,
        duration: CMTime = CMTime(seconds: 0.5, preferredTimescale: 600),
        fromClipId: UUID,
        toClipId: UUID
    ) {
        self.id = id
        self.type = type
        self.duration = duration
        self.fromClipId = fromClipId
        self.toClipId = toClipId
    }

    static func == (lhs: Transition, rhs: Transition) -> Bool {
        lhs.id == rhs.id
    }
}

/// 转场类型
enum TransitionType: String, CaseIterable, Codable {
    case none = "无"
    case crossDissolve = "交叉溶解"
    case fade = "淡入淡出"
    case wipeLeft = "向左擦除"
    case wipeRight = "向右擦除"
    case wipeUp = "向上擦除"
    case wipeDown = "向下擦除"
    case slideLeft = "向左滑动"
    case slideRight = "向右滑动"
    case zoom = "缩放"
    case blur = "模糊"

    var icon: String {
        switch self {
        case .none: return "xmark"
        case .crossDissolve: return "square.on.square"
        case .fade: return "circle.lefthalf.filled"
        case .wipeLeft: return "arrow.left.square"
        case .wipeRight: return "arrow.right.square"
        case .wipeUp: return "arrow.up.square"
        case .wipeDown: return "arrow.down.square"
        case .slideLeft: return "rectangle.lefthalf.inset.filled.arrow.left"
        case .slideRight: return "rectangle.righthalf.inset.filled.arrow.right"
        case .zoom: return "arrow.up.left.and.arrow.down.right"
        case .blur: return "aqi.medium"
        }
    }

    var displayName: String { rawValue }
}

/// 转场指令生成器
class TransitionInstructionBuilder {

    /// 为转场创建视频合成指令
    static func buildInstruction(
        for transition: Transition,
        fromTrack: AVMutableCompositionTrack,
        toTrack: AVMutableCompositionTrack,
        at time: CMTime,
        renderSize: CGSize
    ) -> AVMutableVideoCompositionInstruction {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: time, duration: transition.duration)

        let fromLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: fromTrack)
        let toLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: toTrack)

        let startTime = time
        let endTime = CMTimeAdd(time, transition.duration)

        switch transition.type {
        case .none:
            break

        case .crossDissolve, .fade:
            // 交叉溶解：前一个片段淡出，后一个片段淡入
            fromLayerInstruction.setOpacityRamp(
                fromStartOpacity: 1.0,
                toEndOpacity: 0.0,
                timeRange: CMTimeRange(start: startTime, duration: transition.duration)
            )
            toLayerInstruction.setOpacityRamp(
                fromStartOpacity: 0.0,
                toEndOpacity: 1.0,
                timeRange: CMTimeRange(start: startTime, duration: transition.duration)
            )

        case .wipeLeft:
            applyWipeTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                direction: .left,
                startTime: startTime,
                duration: transition.duration,
                renderSize: renderSize
            )

        case .wipeRight:
            applyWipeTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                direction: .right,
                startTime: startTime,
                duration: transition.duration,
                renderSize: renderSize
            )

        case .wipeUp:
            applyWipeTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                direction: .up,
                startTime: startTime,
                duration: transition.duration,
                renderSize: renderSize
            )

        case .wipeDown:
            applyWipeTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                direction: .down,
                startTime: startTime,
                duration: transition.duration,
                renderSize: renderSize
            )

        case .slideLeft:
            applySlideTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                direction: .left,
                startTime: startTime,
                duration: transition.duration,
                renderSize: renderSize
            )

        case .slideRight:
            applySlideTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                direction: .right,
                startTime: startTime,
                duration: transition.duration,
                renderSize: renderSize
            )

        case .zoom:
            applyZoomTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                startTime: startTime,
                duration: transition.duration,
                renderSize: renderSize
            )

        case .blur:
            // 模糊转场需要使用 CIFilter，这里用淡入淡出代替
            fromLayerInstruction.setOpacityRamp(
                fromStartOpacity: 1.0,
                toEndOpacity: 0.0,
                timeRange: CMTimeRange(start: startTime, duration: transition.duration)
            )
            toLayerInstruction.setOpacityRamp(
                fromStartOpacity: 0.0,
                toEndOpacity: 1.0,
                timeRange: CMTimeRange(start: startTime, duration: transition.duration)
            )
        }

        instruction.layerInstructions = [fromLayerInstruction, toLayerInstruction]
        return instruction
    }

    /// 擦除方向
    private enum WipeDirection {
        case left, right, up, down
    }

    /// 应用擦除转场
    private static func applyWipeTransition(
        from: AVMutableVideoCompositionLayerInstruction,
        to: AVMutableVideoCompositionLayerInstruction,
        direction: WipeDirection,
        startTime: CMTime,
        duration: CMTime,
        renderSize: CGSize
    ) {
        // 擦除效果通过裁剪实现
        let startCrop: CGRect
        let endCrop: CGRect

        switch direction {
        case .left:
            startCrop = CGRect(origin: .zero, size: renderSize)
            endCrop = CGRect(x: renderSize.width, y: 0, width: 0, height: renderSize.height)
        case .right:
            startCrop = CGRect(origin: .zero, size: renderSize)
            endCrop = CGRect(x: 0, y: 0, width: 0, height: renderSize.height)
        case .up:
            startCrop = CGRect(origin: .zero, size: renderSize)
            endCrop = CGRect(x: 0, y: renderSize.height, width: renderSize.width, height: 0)
        case .down:
            startCrop = CGRect(origin: .zero, size: renderSize)
            endCrop = CGRect(x: 0, y: 0, width: renderSize.width, height: 0)
        }

        from.setCropRectangleRamp(
            fromStartCropRectangle: startCrop,
            toEndCropRectangle: endCrop,
            timeRange: CMTimeRange(start: startTime, duration: duration)
        )
    }

    /// 应用滑动转场
    private static func applySlideTransition(
        from: AVMutableVideoCompositionLayerInstruction,
        to: AVMutableVideoCompositionLayerInstruction,
        direction: WipeDirection,
        startTime: CMTime,
        duration: CMTime,
        renderSize: CGSize
    ) {
        let identityTransform = CGAffineTransform.identity

        let fromStartTransform = identityTransform
        let fromEndTransform: CGAffineTransform
        let toStartTransform: CGAffineTransform
        let toEndTransform = identityTransform

        switch direction {
        case .left:
            fromEndTransform = identityTransform.translatedBy(x: -renderSize.width, y: 0)
            toStartTransform = identityTransform.translatedBy(x: renderSize.width, y: 0)
        case .right:
            fromEndTransform = identityTransform.translatedBy(x: renderSize.width, y: 0)
            toStartTransform = identityTransform.translatedBy(x: -renderSize.width, y: 0)
        default:
            fromEndTransform = identityTransform
            toStartTransform = identityTransform
        }

        from.setTransformRamp(
            fromStart: fromStartTransform,
            toEnd: fromEndTransform,
            timeRange: CMTimeRange(start: startTime, duration: duration)
        )

        to.setTransformRamp(
            fromStart: toStartTransform,
            toEnd: toEndTransform,
            timeRange: CMTimeRange(start: startTime, duration: duration)
        )
    }

    /// 应用缩放转场
    private static func applyZoomTransition(
        from: AVMutableVideoCompositionLayerInstruction,
        to: AVMutableVideoCompositionLayerInstruction,
        startTime: CMTime,
        duration: CMTime,
        renderSize: CGSize
    ) {
        let identityTransform = CGAffineTransform.identity
        let centerX = renderSize.width / 2
        let centerY = renderSize.height / 2

        // 前一个片段放大并淡出
        let fromEndTransform = identityTransform
            .translatedBy(x: centerX, y: centerY)
            .scaledBy(x: 2.0, y: 2.0)
            .translatedBy(x: -centerX, y: -centerY)

        from.setTransformRamp(
            fromStart: identityTransform,
            toEnd: fromEndTransform,
            timeRange: CMTimeRange(start: startTime, duration: duration)
        )
        from.setOpacityRamp(
            fromStartOpacity: 1.0,
            toEndOpacity: 0.0,
            timeRange: CMTimeRange(start: startTime, duration: duration)
        )

        // 后一个片段从小变大并淡入
        let toStartTransform = identityTransform
            .translatedBy(x: centerX, y: centerY)
            .scaledBy(x: 0.5, y: 0.5)
            .translatedBy(x: -centerX, y: -centerY)

        to.setTransformRamp(
            fromStart: toStartTransform,
            toEnd: identityTransform,
            timeRange: CMTimeRange(start: startTime, duration: duration)
        )
        to.setOpacityRamp(
            fromStartOpacity: 0.0,
            toEndOpacity: 1.0,
            timeRange: CMTimeRange(start: startTime, duration: duration)
        )
    }
}
