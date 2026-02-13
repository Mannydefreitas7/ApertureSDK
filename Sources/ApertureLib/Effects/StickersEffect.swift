import Foundation
import AVFoundation
import CoreImage
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Sticker Model

struct Sticker: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: StickerType
    var imageName: String?
    var imageData: Data?
    var emoji: String?
    var text: String?

    // Position and transform
    var position: CGPoint
    var scale: CGFloat
    var rotation: CGFloat
    var opacity: CGFloat

    // Timing
    var startTime: Double
    var duration: Double

    // Animation
    var enterAnimation: StickerAnimation
    var exitAnimation: StickerAnimation
    var loopAnimation: StickerLoopAnimation?

    // Style (for text stickers)
    var textStyle: TextStickerStyle?

    init(
        id: UUID = UUID(),
        name: String = "",
        type: StickerType,
        imageName: String? = nil,
        emoji: String? = nil,
        text: String? = nil,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        scale: CGFloat = 1.0,
        rotation: CGFloat = 0,
        opacity: CGFloat = 1.0,
        startTime: Double = 0,
        duration: Double = 3.0,
        enterAnimation: StickerAnimation = .none,
        exitAnimation: StickerAnimation = .none,
        loopAnimation: StickerLoopAnimation? = nil,
        textStyle: TextStickerStyle? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.imageName = imageName
        self.emoji = emoji
        self.text = text
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
        self.startTime = startTime
        self.duration = duration
        self.enterAnimation = enterAnimation
        self.exitAnimation = exitAnimation
        self.loopAnimation = loopAnimation
        self.textStyle = textStyle
    }
}

enum StickerType: String, Codable, CaseIterable {
    case image
    case emoji
    case text
    case animated
    case shape
}

enum StickerAnimation: String, Codable, CaseIterable {
    case none
    case fadeIn
    case fadeOut
    case scaleUp
    case scaleDown
    case slideFromLeft
    case slideFromRight
    case slideFromTop
    case slideFromBottom
    case bounce
    case rotate
    case shake
    case pop
    case typewriter
}

enum StickerLoopAnimation: String, Codable, CaseIterable {
    case none
    case pulse
    case bounce
    case rotate
    case shake
    case float
    case glow
    case swing
    case heartbeat
}

struct TextStickerStyle: Codable {
    var fontName: String
    var fontSize: CGFloat
    var textColor: CodableColor
    var backgroundColor: CodableColor?
    var borderColor: CodableColor?
    var borderWidth: CGFloat
    var cornerRadius: CGFloat
    var shadowColor: CodableColor?
    var shadowRadius: CGFloat
    var shadowOffset: CGSize

    init(
        fontName: String = "Helvetica-Bold",
        fontSize: CGFloat = 32,
        textColor: CodableColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
        backgroundColor: CodableColor? = nil,
        borderColor: CodableColor? = nil,
        borderWidth: CGFloat = 0,
        cornerRadius: CGFloat = 0,
        shadowColor: CodableColor? = nil,
        shadowRadius: CGFloat = 0,
        shadowOffset: CGSize = .zero
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
    }
}

// MARK: - Particle Effect System

struct ParticleEffect: Identifiable, Codable {
    let id: UUID
    var type: ParticleEffectType
    var position: CGPoint
    var emissionArea: CGSize
    var startTime: Double
    var duration: Double
    var intensity: CGFloat
    var customColor: CodableColor?

    init(
        id: UUID = UUID(),
        type: ParticleEffectType,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        emissionArea: CGSize = CGSize(width: 1.0, height: 0.1),
        startTime: Double = 0,
        duration: Double = 5.0,
        intensity: CGFloat = 1.0,
        customColor: CodableColor? = nil
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.emissionArea = emissionArea
        self.startTime = startTime
        self.duration = duration
        self.intensity = intensity
        self.customColor = customColor
    }
}

enum ParticleEffectType: String, Codable, CaseIterable {
    case confetti
    case snow
    case rain
    case fire
    case sparkles
    case hearts
    case stars
    case bubbles
    case smoke
    case leaves
    case petals
    case fireworks
    case dust
    case magic
    case coins
    case emojis

    var displayName: String {
        switch self {
        case .confetti: return "彩纸"
        case .snow: return "雪花"
        case .rain: return "雨滴"
        case .fire: return "火焰"
        case .sparkles: return "闪光"
        case .hearts: return "爱心"
        case .stars: return "星星"
        case .bubbles: return "气泡"
        case .smoke: return "烟雾"
        case .leaves: return "落叶"
        case .petals: return "花瓣"
        case .fireworks: return "烟花"
        case .dust: return "灰尘"
        case .magic: return "魔法"
        case .coins: return "金币"
        case .emojis: return "表情"
        }
    }
}

// MARK: - Frame/Border Templates

struct FrameTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: FrameType
    var imageName: String?
    var color: CodableColor?
    var borderWidth: CGFloat
    var cornerRadius: CGFloat
    var aspectRatio: CGFloat?

    init(
        id: UUID = UUID(),
        name: String,
        type: FrameType,
        imageName: String? = nil,
        color: CodableColor? = nil,
        borderWidth: CGFloat = 0,
        cornerRadius: CGFloat = 0,
        aspectRatio: CGFloat? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.imageName = imageName
        self.color = color
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.aspectRatio = aspectRatio
    }
}

enum FrameType: String, Codable, CaseIterable {
    case none
    case solidBorder
    case gradientBorder
    case imageBorder
    case decorative
    case polaroid
    case filmStrip
    case vintage
    case neon
    case shadow
}

// MARK: - Sticker Manager

class StickerManager: ObservableObject {
    static let shared = StickerManager()

    @Published var stickers: [Sticker] = []
    @Published var particleEffects: [ParticleEffect] = []
    @Published var selectedFrame: FrameTemplate?

    // Built-in emoji stickers
    let emojiCategories: [String: [String]] = [
        "表情": ["😀", "😂", "🥰", "😍", "🤩", "😎", "🥳", "😇", "🤔", "😴", "😭", "😱", "🤯", "🥶", "🤮"],
        "手势": ["👍", "👎", "👏", "🙌", "🤝", "✌️", "🤞", "🤟", "🤘", "👌", "🤙", "💪", "🙏", "✍️", "🖐️"],
        "爱心": ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "💕", "💞", "💓", "💗", "💖", "💘", "💝"],
        "动物": ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵"],
        "食物": ["🍎", "🍊", "🍋", "🍇", "🍓", "🍔", "🍕", "🍟", "🍿", "🍩", "🍪", "🎂", "🍰", "🧁", "☕"],
        "符号": ["⭐", "🌟", "✨", "💫", "🔥", "💥", "💯", "✅", "❌", "❓", "❗", "💬", "🎵", "🎶", "🎭"]
    ]

    // Built-in shape stickers
    let shapeStickers: [String] = [
        "circle", "square", "triangle", "star", "heart",
        "arrow_up", "arrow_down", "arrow_left", "arrow_right",
        "speech_bubble", "thought_bubble", "banner", "ribbon"
    ]

    // Built-in frame templates
    let builtInFrames: [FrameTemplate] = [
        FrameTemplate(name: "无边框", type: .none),
        FrameTemplate(name: "白色边框", type: .solidBorder, color: CodableColor(red: 1, green: 1, blue: 1, alpha: 1), borderWidth: 20),
        FrameTemplate(name: "黑色边框", type: .solidBorder, color: CodableColor(red: 0, green: 0, blue: 0, alpha: 1), borderWidth: 20),
        FrameTemplate(name: "拍立得", type: .polaroid, borderWidth: 15, cornerRadius: 0),
        FrameTemplate(name: "胶片", type: .filmStrip),
        FrameTemplate(name: "复古", type: .vintage, cornerRadius: 10),
        FrameTemplate(name: "霓虹", type: .neon, borderWidth: 5),
        FrameTemplate(name: "阴影", type: .shadow, cornerRadius: 15)
    ]

    private init() {}

    // MARK: - Sticker Operations

    func addSticker(_ sticker: Sticker) {
        stickers.append(sticker)
    }

    func removeSticker(_ sticker: Sticker) {
        stickers.removeAll { $0.id == sticker.id }
    }

    func updateSticker(_ sticker: Sticker) {
        if let index = stickers.firstIndex(where: { $0.id == sticker.id }) {
            stickers[index] = sticker
        }
    }

    func duplicateSticker(_ sticker: Sticker) {
        var newSticker = sticker
        newSticker.position.x += 0.05
        newSticker.position.y += 0.05
        stickers.append(Sticker(
            name: sticker.name,
            type: sticker.type,
            imageName: sticker.imageName,
            emoji: sticker.emoji,
            text: sticker.text,
            position: newSticker.position,
            scale: sticker.scale,
            rotation: sticker.rotation,
            opacity: sticker.opacity,
            startTime: sticker.startTime,
            duration: sticker.duration,
            enterAnimation: sticker.enterAnimation,
            exitAnimation: sticker.exitAnimation,
            loopAnimation: sticker.loopAnimation,
            textStyle: sticker.textStyle
        ))
    }

    // MARK: - Particle Effect Operations

    func addParticleEffect(_ effect: ParticleEffect) {
        particleEffects.append(effect)
    }

    func removeParticleEffect(_ effect: ParticleEffect) {
        particleEffects.removeAll { $0.id == effect.id }
    }

    func updateParticleEffect(_ effect: ParticleEffect) {
        if let index = particleEffects.firstIndex(where: { $0.id == effect.id }) {
            particleEffects[index] = effect
        }
    }

    // MARK: - Create Common Stickers

    func createEmojiSticker(emoji: String, at position: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> Sticker {
        Sticker(
            name: emoji,
            type: .emoji,
            emoji: emoji,
            position: position,
            scale: 1.0,
            enterAnimation: .pop,
            loopAnimation: .pulse
        )
    }

    func createTextSticker(
        text: String,
        style: TextStickerStyle = TextStickerStyle(),
        at position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> Sticker {
        Sticker(
            name: text,
            type: .text,
            text: text,
            position: position,
            scale: 1.0,
            enterAnimation: .fadeIn,
            textStyle: style
        )
    }

    func createImageSticker(
        imageName: String,
        at position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> Sticker {
        Sticker(
            name: imageName,
            type: .image,
            imageName: imageName,
            position: position,
            scale: 1.0,
            enterAnimation: .scaleUp
        )
    }

    // MARK: - Render Stickers to Video

    func renderStickersToComposition(
        composition: AVMutableComposition,
        videoSize: CGSize
    ) -> AVVideoComposition? {
        // Create video composition for overlay
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // Get video track
        guard let videoTrack = composition.tracks(withMediaType: .video).first else {
            return nil
        }

        // Create instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(
            start: .zero,
            duration: composition.duration
        )

        // Create layer instruction
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        instruction.layerInstructions = [layerInstruction]

        videoComposition.instructions = [instruction]

        // Add overlay layer with stickers
        let overlayLayer = createStickerOverlayLayer(size: videoSize, duration: composition.duration.seconds)
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        return videoComposition
    }

    private func createStickerOverlayLayer(size: CGSize, duration: Double) -> CALayer {
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: size)

        for sticker in stickers {
            let stickerLayer = createStickerLayer(sticker, videoSize: size)
            addStickerAnimations(to: stickerLayer, sticker: sticker, duration: duration)
            overlayLayer.addSublayer(stickerLayer)
        }

        return overlayLayer
    }

    private func createStickerLayer(_ sticker: Sticker, videoSize: CGSize) -> CALayer {
        let layer = CALayer()

        let stickerSize = CGSize(width: 100 * sticker.scale, height: 100 * sticker.scale)
        let position = CGPoint(
            x: sticker.position.x * videoSize.width,
            y: (1 - sticker.position.y) * videoSize.height // Flip Y for video coordinates
        )

        layer.frame = CGRect(
            x: position.x - stickerSize.width / 2,
            y: position.y - stickerSize.height / 2,
            width: stickerSize.width,
            height: stickerSize.height
        )
        layer.opacity = Float(sticker.opacity)

        switch sticker.type {
        case .emoji:
            if let emoji = sticker.emoji {
                let textLayer = CATextLayer()
                textLayer.string = emoji
                textLayer.fontSize = 80 * sticker.scale
                textLayer.alignmentMode = .center
                textLayer.frame = layer.bounds
                textLayer.contentsScale = 2.0
                layer.addSublayer(textLayer)
            }

        case .text:
            if let text = sticker.text, let style = sticker.textStyle {
                let textLayer = CATextLayer()
                textLayer.string = text
                textLayer.fontSize = style.fontSize * sticker.scale
                textLayer.foregroundColor = style.textColor.cgColor
                textLayer.alignmentMode = .center
                textLayer.frame = layer.bounds
                textLayer.contentsScale = 2.0

                if let bgColor = style.backgroundColor {
                    textLayer.backgroundColor = bgColor.cgColor
                    textLayer.cornerRadius = style.cornerRadius
                }

                layer.addSublayer(textLayer)
            }

        case .image:
            if let imageName = sticker.imageName {
                #if canImport(AppKit)
                if let image = NSImage(named: imageName) {
                    layer.contents = image
                }
                #elseif canImport(UIKit)
                if let image = UIImage(named: imageName) {
                    layer.contents = image.cgImage
                }
                #endif
            }

        case .animated, .shape:
            // Handle animated and shape stickers
            break
        }

        return layer
    }

    private func addStickerAnimations(to layer: CALayer, sticker: Sticker, duration: Double) {
        let beginTime = sticker.startTime
        let endTime = sticker.startTime + sticker.duration

        // Initially hidden
        layer.opacity = 0

        // Show/hide animation
        let showAnimation = CABasicAnimation(keyPath: "opacity")
        showAnimation.fromValue = 0
        showAnimation.toValue = Float(sticker.opacity)
        showAnimation.beginTime = beginTime
        showAnimation.duration = 0.01
        showAnimation.fillMode = .forwards
        showAnimation.isRemovedOnCompletion = false
        layer.add(showAnimation, forKey: "show")

        // Enter animation
        addEnterAnimation(to: layer, animation: sticker.enterAnimation, beginTime: beginTime)

        // Loop animation
        if let loopAnim = sticker.loopAnimation, loopAnim != .none {
            addLoopAnimation(to: layer, animation: loopAnim, beginTime: beginTime, duration: sticker.duration)
        }

        // Exit animation
        addExitAnimation(to: layer, animation: sticker.exitAnimation, beginTime: endTime - 0.3)

        // Hide at end
        let hideAnimation = CABasicAnimation(keyPath: "opacity")
        hideAnimation.fromValue = Float(sticker.opacity)
        hideAnimation.toValue = 0
        hideAnimation.beginTime = endTime
        hideAnimation.duration = 0.01
        hideAnimation.fillMode = .forwards
        hideAnimation.isRemovedOnCompletion = false
        layer.add(hideAnimation, forKey: "hide")
    }

    private func addEnterAnimation(to layer: CALayer, animation: StickerAnimation, beginTime: Double) {
        switch animation {
        case .none:
            break

        case .fadeIn:
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = 0
            anim.toValue = 1
            anim.beginTime = beginTime
            anim.duration = 0.3
            anim.fillMode = .forwards
            layer.add(anim, forKey: "fadeIn")

        case .scaleUp:
            let anim = CABasicAnimation(keyPath: "transform.scale")
            anim.fromValue = 0
            anim.toValue = 1
            anim.beginTime = beginTime
            anim.duration = 0.3
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(anim, forKey: "scaleUp")

        case .pop:
            let anim = CAKeyframeAnimation(keyPath: "transform.scale")
            anim.values = [0, 1.2, 0.9, 1.0]
            anim.keyTimes = [0, 0.4, 0.7, 1.0]
            anim.beginTime = beginTime
            anim.duration = 0.4
            layer.add(anim, forKey: "pop")

        case .bounce:
            let anim = CAKeyframeAnimation(keyPath: "position.y")
            let startY = layer.position.y
            anim.values = [startY - 50, startY + 10, startY - 5, startY]
            anim.keyTimes = [0, 0.5, 0.75, 1.0]
            anim.beginTime = beginTime
            anim.duration = 0.5
            layer.add(anim, forKey: "bounce")

        case .slideFromLeft:
            let anim = CABasicAnimation(keyPath: "position.x")
            anim.fromValue = -layer.bounds.width
            anim.toValue = layer.position.x
            anim.beginTime = beginTime
            anim.duration = 0.3
            layer.add(anim, forKey: "slideFromLeft")

        case .slideFromRight:
            let anim = CABasicAnimation(keyPath: "position.x")
            anim.fromValue = layer.superlayer?.bounds.width ?? 1920
            anim.toValue = layer.position.x
            anim.beginTime = beginTime
            anim.duration = 0.3
            layer.add(anim, forKey: "slideFromRight")

        case .slideFromTop:
            let anim = CABasicAnimation(keyPath: "position.y")
            anim.fromValue = layer.superlayer?.bounds.height ?? 1080
            anim.toValue = layer.position.y
            anim.beginTime = beginTime
            anim.duration = 0.3
            layer.add(anim, forKey: "slideFromTop")

        case .slideFromBottom:
            let anim = CABasicAnimation(keyPath: "position.y")
            anim.fromValue = -layer.bounds.height
            anim.toValue = layer.position.y
            anim.beginTime = beginTime
            anim.duration = 0.3
            layer.add(anim, forKey: "slideFromBottom")

        case .rotate:
            let anim = CABasicAnimation(keyPath: "transform.rotation.z")
            anim.fromValue = -Double.pi
            anim.toValue = 0
            anim.beginTime = beginTime
            anim.duration = 0.4
            layer.add(anim, forKey: "rotateIn")

        case .shake:
            let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            anim.values = [-0.2, 0.2, -0.15, 0.15, -0.1, 0.1, 0]
            anim.beginTime = beginTime
            anim.duration = 0.4
            layer.add(anim, forKey: "shakeIn")

        default:
            break
        }
    }

    private func addLoopAnimation(to layer: CALayer, animation: StickerLoopAnimation, beginTime: Double, duration: Double) {
        switch animation {
        case .none:
            break

        case .pulse:
            let anim = CABasicAnimation(keyPath: "transform.scale")
            anim.fromValue = 1.0
            anim.toValue = 1.1
            anim.autoreverses = true
            anim.repeatCount = Float(duration / 0.5)
            anim.beginTime = beginTime
            anim.duration = 0.5
            layer.add(anim, forKey: "pulse")

        case .bounce:
            let anim = CAKeyframeAnimation(keyPath: "position.y")
            let startY = layer.position.y
            anim.values = [startY, startY - 10, startY]
            anim.keyTimes = [0, 0.5, 1.0]
            anim.repeatCount = Float(duration / 0.6)
            anim.beginTime = beginTime
            anim.duration = 0.6
            layer.add(anim, forKey: "bounceLoop")

        case .rotate:
            let anim = CABasicAnimation(keyPath: "transform.rotation.z")
            anim.fromValue = 0
            anim.toValue = Double.pi * 2
            anim.repeatCount = Float(duration / 2.0)
            anim.beginTime = beginTime
            anim.duration = 2.0
            layer.add(anim, forKey: "rotateLoop")

        case .shake:
            let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            anim.values = [-0.1, 0.1, -0.1]
            anim.repeatCount = Float(duration / 0.3)
            anim.beginTime = beginTime
            anim.duration = 0.3
            layer.add(anim, forKey: "shakeLoop")

        case .float:
            let anim = CAKeyframeAnimation(keyPath: "position.y")
            let startY = layer.position.y
            anim.values = [startY, startY - 15, startY]
            anim.keyTimes = [0, 0.5, 1.0]
            anim.repeatCount = Float(duration / 2.0)
            anim.beginTime = beginTime
            anim.duration = 2.0
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(anim, forKey: "float")

        case .glow:
            let anim = CABasicAnimation(keyPath: "shadowOpacity")
            anim.fromValue = 0.5
            anim.toValue = 1.0
            anim.autoreverses = true
            anim.repeatCount = Float(duration / 0.8)
            anim.beginTime = beginTime
            anim.duration = 0.8
            layer.shadowColor = CGColor(red: 1, green: 1, blue: 0, alpha: 1)
            layer.shadowRadius = 10
            layer.add(anim, forKey: "glow")

        case .swing:
            let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            anim.values = [-0.15, 0.15, -0.15]
            anim.keyTimes = [0, 0.5, 1.0]
            anim.repeatCount = Float(duration / 1.0)
            anim.beginTime = beginTime
            anim.duration = 1.0
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(anim, forKey: "swing")

        case .heartbeat:
            let anim = CAKeyframeAnimation(keyPath: "transform.scale")
            anim.values = [1.0, 1.15, 1.0, 1.1, 1.0]
            anim.keyTimes = [0, 0.15, 0.3, 0.45, 1.0]
            anim.repeatCount = Float(duration / 1.0)
            anim.beginTime = beginTime
            anim.duration = 1.0
            layer.add(anim, forKey: "heartbeat")
        }
    }

    private func addExitAnimation(to layer: CALayer, animation: StickerAnimation, beginTime: Double) {
        switch animation {
        case .none, .fadeIn, .slideFromLeft, .slideFromRight, .slideFromTop, .slideFromBottom, .typewriter:
            break

        case .fadeOut:
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = 1
            anim.toValue = 0
            anim.beginTime = beginTime
            anim.duration = 0.3
            anim.fillMode = .forwards
            layer.add(anim, forKey: "fadeOut")

        case .scaleUp:
            let anim = CABasicAnimation(keyPath: "transform.scale")
            anim.fromValue = 1
            anim.toValue = 1.5
            anim.beginTime = beginTime
            anim.duration = 0.3
            layer.add(anim, forKey: "scaleUpExit")

        case .scaleDown:
            let anim = CABasicAnimation(keyPath: "transform.scale")
            anim.fromValue = 1
            anim.toValue = 0
            anim.beginTime = beginTime
            anim.duration = 0.3
            layer.add(anim, forKey: "scaleDown")

        case .pop, .bounce:
            let anim = CABasicAnimation(keyPath: "transform.scale")
            anim.fromValue = 1
            anim.toValue = 0
            anim.beginTime = beginTime
            anim.duration = 0.2
            anim.timingFunction = CAMediaTimingFunction(name: .easeIn)
            layer.add(anim, forKey: "popOut")

        case .rotate:
            let anim = CABasicAnimation(keyPath: "transform.rotation.z")
            anim.fromValue = 0
            anim.toValue = Double.pi
            anim.beginTime = beginTime
            anim.duration = 0.3
            layer.add(anim, forKey: "rotateOut")

        case .shake:
            let anim = CAKeyframeAnimation(keyPath: "position.x")
            let startX = layer.position.x
            anim.values = [startX, startX - 10, startX + 10, startX - 10, startX + 10, startX]
            anim.beginTime = beginTime
            anim.duration = 0.3
            layer.add(anim, forKey: "shakeOut")
        }
    }

    // MARK: - Serialization

    func exportData() -> Data? {
        let data = StickerEffectsData(
            stickers: stickers,
            particleEffects: particleEffects,
            selectedFrame: selectedFrame
        )
        return try? JSONEncoder().encode(data)
    }

    func importData(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode(StickerEffectsData.self, from: data) else {
            return
        }
        stickers = decoded.stickers
        particleEffects = decoded.particleEffects
        selectedFrame = decoded.selectedFrame
    }

    func clearAll() {
        stickers.removeAll()
        particleEffects.removeAll()
        selectedFrame = nil
    }
}

struct StickerEffectsData: Codable {
    var stickers: [Sticker]
    var particleEffects: [ParticleEffect]
    var selectedFrame: FrameTemplate?
}

// MARK: - Particle Emitter (for preview)

#if canImport(UIKit)
import QuartzCore

class ParticleEmitterView: UIView {
    private var emitterLayer: CAEmitterLayer?

    func configure(with effect: ParticleEffect) {
        emitterLayer?.removeFromSuperlayer()

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(
            x: bounds.width * effect.position.x,
            y: bounds.height * effect.position.y
        )
        emitter.emitterSize = CGSize(
            width: bounds.width * effect.emissionArea.width,
            height: bounds.height * effect.emissionArea.height
        )
        emitter.emitterShape = .line

        let cell = createEmitterCell(for: effect)
        emitter.emitterCells = [cell]

        layer.addSublayer(emitter)
        emitterLayer = emitter
    }

    private func createEmitterCell(for effect: ParticleEffect) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.birthRate = Float(10 * effect.intensity)
        cell.lifetime = 5.0
        cell.velocity = 100
        cell.velocityRange = 50
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 4
        cell.scale = 0.1
        cell.scaleRange = 0.05

        switch effect.type {
        case .confetti:
            cell.contents = createConfettiImage()?.cgImage
            cell.color = UIColor.random.cgColor

        case .snow:
            cell.contents = createCircleImage(color: .white)?.cgImage
            cell.velocity = 50

        case .hearts:
            cell.contents = createHeartImage()?.cgImage
            cell.color = UIColor.red.cgColor

        case .stars:
            cell.contents = createStarImage()?.cgImage
            cell.color = UIColor.yellow.cgColor

        default:
            cell.contents = createCircleImage(color: .white)?.cgImage
        }

        return cell
    }

    private func createConfettiImage() -> UIImage? {
        let size = CGSize(width: 10, height: 10)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    private func createCircleImage(color: UIColor) -> UIImage? {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    private func createHeartImage() -> UIImage? {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.red.setFill()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 10, y: 18))
        path.addCurve(to: CGPoint(x: 2, y: 6), controlPoint1: CGPoint(x: 2, y: 14), controlPoint2: CGPoint(x: 2, y: 10))
        path.addArc(withCenter: CGPoint(x: 6, y: 6), radius: 4, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addArc(withCenter: CGPoint(x: 14, y: 6), radius: 4, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addCurve(to: CGPoint(x: 10, y: 18), controlPoint1: CGPoint(x: 18, y: 10), controlPoint2: CGPoint(x: 18, y: 14))
        path.fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    private func createStarImage() -> UIImage? {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.yellow.setFill()
        let path = UIBezierPath()
        let center = CGPoint(x: 10, y: 10)
        let points = 5
        let innerRadius: CGFloat = 4
        let outerRadius: CGFloat = 10

        for i in 0..<points * 2 {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()
        path.fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

extension UIColor {
    static var random: UIColor {
        UIColor(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1),
            alpha: 1
        )
    }
}
#endif
