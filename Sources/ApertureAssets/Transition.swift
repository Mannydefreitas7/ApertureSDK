import Foundation
import AVFoundation
import CoreImage
@_exported import ApertureCore

/// Transition instruction builder for AVFoundation rendering
public class TransitionInstructionBuilder {

    /// Build video composition instruction for a transition
    public static func buildInstruction(
        for transition: Transition,
        fromTrack: AVMutableCompositionTrack,
        toTrack: AVMutableCompositionTrack,
        at time: CMTime,
        renderSize: CGSize
    ) -> AVMutableVideoCompositionInstruction {
        let instruction = AVMutableVideoCompositionInstruction()
        let duration = CMTime(seconds: transition.duration, preferredTimescale: 600)
        instruction.timeRange = CMTimeRange(start: time, duration: duration)

        let fromLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: fromTrack)
        let toLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: toTrack)

        let startTime = time
        let endTime = CMTimeAdd(time, duration)

        switch transition.type {
        case .none:
            break

        case .crossDissolve, .fade, .dissolve:
            // Cross dissolve: fade out the first clip, fade in the second
            fromLayerInstruction.setOpacityRamp(
                fromStartOpacity: 1.0,
                toEndOpacity: 0.0,
                timeRange: CMTimeRange(start: startTime, duration: duration)
            )
            toLayerInstruction.setOpacityRamp(
                fromStartOpacity: 0.0,
                toEndOpacity: 1.0,
                timeRange: CMTimeRange(start: startTime, duration: duration)
            )

        case .wipeLeft:
            applyWipeTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                direction: .left,
                startTime: startTime,
                duration: duration,
                renderSize: renderSize
            )

        case .wipeRight:
            applyWipeTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                direction: .right,
                startTime: startTime,
                duration: duration,
                renderSize: renderSize
            )

        case .wipeUp:
            applyWipeTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                direction: .up,
                startTime: startTime,
                duration: duration,
                renderSize: renderSize
            )

        case .wipeDown:
            applyWipeTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                direction: .down,
                startTime: startTime,
                duration: duration,
                renderSize: renderSize
            )

        case .slideLeft, .slideRight, .slideUp, .slideDown:
            applySlideTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                direction: transition.type == .slideLeft ? .left :
                          transition.type == .slideRight ? .right :
                          transition.type == .slideUp ? .up : .down,
                startTime: startTime,
                duration: duration,
                renderSize: renderSize
            )

        case .zoom:
            applyZoomTransition(
                from: fromLayerInstruction,
                to: toLayerInstruction,
                startTime: startTime,
                duration: duration,
                renderSize: renderSize
            )

        case .blur:
            // Blur transition requires CIFilter, using fade as fallback
            fromLayerInstruction.setOpacityRamp(
                fromStartOpacity: 1.0,
                toEndOpacity: 0.0,
                timeRange: CMTimeRange(start: startTime, duration: duration)
            )
            toLayerInstruction.setOpacityRamp(
                fromStartOpacity: 0.0,
                toEndOpacity: 1.0,
                timeRange: CMTimeRange(start: startTime, duration: duration)
            )
        }

        instruction.layerInstructions = [fromLayerInstruction, toLayerInstruction]
        return instruction
    }

    /// Wipe direction
    public enum WipeDirection {
        case left, right, up, down
    }

    /// Apply wipe transition
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

    /// Apply zoom transition
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

        // First clip zooms in and fades out
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

        // Second clip zooms from small and fades in
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
