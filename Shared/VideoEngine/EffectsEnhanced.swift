import Foundation
import AVFoundation
import CoreImage
import CoreGraphics
import simd
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - 5. 特效增强模块

// MARK: - 3D 标题

struct Title3D: Identifiable, Codable {
    let id: UUID
    var text: String
    var font: String
    var fontSize: CGFloat
    var depth: CGFloat
    var rotation: SIMD3<Float>  // x, y, z 旋转角度
    var position: SIMD3<Float>
    var color: CodableColor
    var materialType: Material3DType
    var animation: Title3DAnimation?

    init(
        id: UUID = UUID(),
        text: String,
        font: String = "Helvetica-Bold",
        fontSize: CGFloat = 72,
        depth: CGFloat = 20,
        rotation: SIMD3<Float> = .zero,
        position: SIMD3<Float> = .zero,
        color: CodableColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
        materialType: Material3DType = .metallic,
        animation: Title3DAnimation? = nil
    ) {
        self.id = id
        self.text = text
        self.font = font
        self.fontSize = fontSize
        self.depth = depth
        self.rotation = rotation
        self.position = position
        self.color = color
        self.materialType = materialType
        self.animation = animation
    }
}

enum Material3DType: String, Codable, CaseIterable {
    case matte = "哑光"
    case metallic = "金属"
    case glass = "玻璃"
    case neon = "霓虹"
    case chrome = "镀铬"
    case gold = "金色"
    case wood = "木质"
    case plastic = "塑料"
}

struct Title3DAnimation: Codable {
    var type: Title3DAnimationType
    var duration: Double
    var delay: Double
    var easing: EasingFunction
}

enum Title3DAnimationType: String, Codable, CaseIterable {
    case flyIn = "飞入"
    case rotateIn = "旋转进入"
    case scaleUp = "放大进入"
    case explode = "爆炸"
    case assemble = "组装"
    case typewriter = "打字机"
    case wave = "波浪"
    case bounce = "弹跳"
}

class Title3DRenderer: ObservableObject {
    static let shared = Title3DRenderer()

    @Published var titles: [Title3D] = []

    private init() {}

    // 渲染3D标题到图像
    func render(_ title: Title3D, size: CGSize, time: Double) -> CIImage? {
        // 使用 SceneKit 或 Metal 渲染3D文字
        // 简化实现：返回2D模拟效果

        // 创建文字图像
        let textImage = createTextImage(title, size: size)

        // 应用3D变换效果
        var result = textImage

        // 透视变换
        result = applyPerspective(result, rotation: title.rotation)

        // 添加阴影和深度效果
        result = addDepthEffect(result, depth: title.depth, material: title.materialType)

        return result
    }

    private func createTextImage(_ title: Title3D, size: CGSize) -> CIImage {
        // 创建文字渲染
        #if canImport(AppKit)
        let nsImage = NSImage(size: size)
        nsImage.lockFocus()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let font = NSFont(name: title.font, size: title.fontSize) ?? NSFont.systemFont(ofSize: title.fontSize)
        let color = NSColor(
            red: title.color.red,
            green: title.color.green,
            blue: title.color.blue,
            alpha: title.color.alpha
        )

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let textRect = CGRect(x: 0, y: size.height / 2 - title.fontSize, width: size.width, height: title.fontSize * 2)
        title.text.draw(in: textRect, withAttributes: attrs)
        nsImage.unlockFocus()

        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return CIImage()
        }
        return CIImage(cgImage: cgImage)
        #else
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: title.font, size: title.fontSize) ?? UIFont.systemFont(ofSize: title.fontSize),
                .foregroundColor: UIColor(
                    red: title.color.red,
                    green: title.color.green,
                    blue: title.color.blue,
                    alpha: title.color.alpha
                ),
                .paragraphStyle: paragraphStyle
            ]

            let textRect = CGRect(x: 0, y: size.height / 2 - title.fontSize, width: size.width, height: title.fontSize * 2)
            title.text.draw(in: textRect, withAttributes: attrs)
        }

        return CIImage(image: image) ?? CIImage()
        #endif
    }

    private func applyPerspective(_ image: CIImage, rotation: SIMD3<Float>) -> CIImage {
        guard let filter = CIFilter(name: "CIPerspectiveTransform") else {
            return image
        }

        let extent = image.extent
        let rotationRadians = rotation * Float.pi / 180

        // 简化的透视变换
        let topLeft = CGPoint(x: extent.minX, y: extent.minY)
        let topRight = CGPoint(x: extent.maxX, y: extent.minY)
        let bottomLeft = CGPoint(x: extent.minX, y: extent.maxY)
        let bottomRight = CGPoint(x: extent.maxX, y: extent.maxY)

        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        filter.setValue(image, forKey: kCIInputImageKey)

        return filter.outputImage ?? image
    }

    private func addDepthEffect(_ image: CIImage, depth: CGFloat, material: Material3DType) -> CIImage {
        var result = image

        // 添加阴影
        if let shadow = CIFilter(name: "CIDropShadow") {
            shadow.setValue(result, forKey: kCIInputImageKey)
            shadow.setValue(depth / 2, forKey: "inputRadius")
            shadow.setValue(CIVector(x: depth / 4, y: -depth / 4), forKey: "inputOffset")
            if let output = shadow.outputImage {
                result = output
            }
        }

        // 根据材质添加效果
        switch material {
        case .metallic, .chrome, .gold:
            // 添加高光
            if let bloom = CIFilter(name: "CIBloom") {
                bloom.setValue(result, forKey: kCIInputImageKey)
                bloom.setValue(5.0, forKey: kCIInputRadiusKey)
                bloom.setValue(0.5, forKey: kCIInputIntensityKey)
                if let output = bloom.outputImage {
                    result = output
                }
            }
        case .neon:
            // 添加发光效果
            if let glow = CIFilter(name: "CIGloom") {
                glow.setValue(result, forKey: kCIInputImageKey)
                glow.setValue(10.0, forKey: kCIInputRadiusKey)
                glow.setValue(1.0, forKey: kCIInputIntensityKey)
                if let output = glow.outputImage {
                    result = output
                }
            }
        case .glass:
            // 添加透明效果
            if let opacity = CIFilter(name: "CIColorMatrix") {
                opacity.setValue(result, forKey: kCIInputImageKey)
                opacity.setValue(CIVector(x: 0, y: 0, z: 0, w: 0.7), forKey: "inputAVector")
                if let output = opacity.outputImage {
                    result = output
                }
            }
        default:
            break
        }

        return result
    }
}

// MARK: - 光效系统

enum LightEffectType: String, CaseIterable, Codable {
    case lensFlare = "镜头光晕"
    case sunbeams = "阳光射线"
    case bokeh = "光斑"
    case volumetricLight = "体积光"
    case glow = "辉光"
    case sparkle = "闪烁"
    case lightLeak = "漏光"
    case anamorphicFlare = "变形光晕"
}

struct LightEffect: Identifiable, Codable {
    let id: UUID
    var type: LightEffectType
    var position: CGPoint  // 归一化坐标
    var intensity: Float
    var color: CodableColor
    var size: Float
    var rotation: Float
    var animated: Bool
    var animationSpeed: Float

    init(
        id: UUID = UUID(),
        type: LightEffectType,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        intensity: Float = 1.0,
        color: CodableColor = CodableColor(red: 1, green: 0.9, blue: 0.8, alpha: 1),
        size: Float = 1.0,
        rotation: Float = 0,
        animated: Bool = false,
        animationSpeed: Float = 1.0
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.intensity = intensity
        self.color = color
        self.size = size
        self.rotation = rotation
        self.animated = animated
        self.animationSpeed = animationSpeed
    }
}

class LightEffectRenderer: ObservableObject {
    static let shared = LightEffectRenderer()

    @Published var effects: [LightEffect] = []

    private init() {}

    // 应用光效
    func apply(_ effect: LightEffect, to image: CIImage, time: Double = 0) -> CIImage {
        let size = image.extent.size
        let position = CGPoint(
            x: effect.position.x * size.width,
            y: effect.position.y * size.height
        )

        var animatedIntensity = effect.intensity
        if effect.animated {
            animatedIntensity *= Float(0.5 + 0.5 * sin(time * Double(effect.animationSpeed) * 2 * .pi))
        }

        switch effect.type {
        case .lensFlare:
            return applyLensFlare(to: image, at: position, intensity: animatedIntensity, color: effect.color)
        case .sunbeams:
            return applySunbeams(to: image, at: position, intensity: animatedIntensity)
        case .bokeh:
            return applyBokeh(to: image, intensity: animatedIntensity, color: effect.color)
        case .glow:
            return applyGlow(to: image, intensity: animatedIntensity, color: effect.color)
        case .lightLeak:
            return applyLightLeak(to: image, intensity: animatedIntensity, color: effect.color)
        default:
            return image
        }
    }

    private func applyLensFlare(to image: CIImage, at position: CGPoint, intensity: Float, color: CodableColor) -> CIImage {
        guard let filter = CIFilter(name: "CISunbeamsGenerator") else {
            return image
        }

        filter.setValue(CIVector(cgPoint: position), forKey: "inputCenter")
        filter.setValue(CIColor(red: color.red, green: color.green, blue: color.blue), forKey: "inputColor")
        filter.setValue(intensity * 100, forKey: "inputSunRadius")
        filter.setValue(intensity * 2, forKey: "inputMaxStriationRadius")

        guard let flare = filter.outputImage?.cropped(to: image.extent),
              let blend = CIFilter(name: "CIAdditionCompositing") else {
            return image
        }

        blend.setValue(image, forKey: kCIInputImageKey)
        blend.setValue(flare, forKey: kCIInputBackgroundImageKey)

        return blend.outputImage ?? image
    }

    private func applySunbeams(to image: CIImage, at position: CGPoint, intensity: Float) -> CIImage {
        guard let filter = CIFilter(name: "CISunbeamsGenerator") else {
            return image
        }

        filter.setValue(CIVector(cgPoint: position), forKey: "inputCenter")
        filter.setValue(intensity * 150, forKey: "inputSunRadius")
        filter.setValue(intensity * 3, forKey: "inputMaxStriationRadius")
        filter.setValue(0.5, forKey: "inputStriationStrength")

        guard let beams = filter.outputImage?.cropped(to: image.extent),
              let blend = CIFilter(name: "CIScreenBlendMode") else {
            return image
        }

        blend.setValue(image, forKey: kCIInputImageKey)
        blend.setValue(beams, forKey: kCIInputBackgroundImageKey)

        return blend.outputImage ?? image
    }

    private func applyBokeh(to image: CIImage, intensity: Float, color: CodableColor) -> CIImage {
        guard let blur = CIFilter(name: "CIDiscBlur") else {
            return image
        }

        blur.setValue(image, forKey: kCIInputImageKey)
        blur.setValue(intensity * 10, forKey: kCIInputRadiusKey)

        return blur.outputImage?.cropped(to: image.extent) ?? image
    }

    private func applyGlow(to image: CIImage, intensity: Float, color: CodableColor) -> CIImage {
        guard let bloom = CIFilter(name: "CIBloom") else {
            return image
        }

        bloom.setValue(image, forKey: kCIInputImageKey)
        bloom.setValue(intensity * 20, forKey: kCIInputRadiusKey)
        bloom.setValue(intensity, forKey: kCIInputIntensityKey)

        return bloom.outputImage ?? image
    }

    private func applyLightLeak(to image: CIImage, intensity: Float, color: CodableColor) -> CIImage {
        // 创建渐变光晕
        guard let gradient = CIFilter(name: "CIRadialGradient") else {
            return image
        }

        let center = CGPoint(x: image.extent.width * 0.8, y: image.extent.height * 0.2)
        gradient.setValue(CIVector(cgPoint: center), forKey: "inputCenter0")
        gradient.setValue(CIVector(cgPoint: center), forKey: "inputCenter1")
        gradient.setValue(0, forKey: "inputRadius0")
        gradient.setValue(image.extent.width * 0.5, forKey: "inputRadius1")
        gradient.setValue(CIColor(red: color.red, green: color.green, blue: color.blue, alpha: CGFloat(intensity)), forKey: "inputColor0")
        gradient.setValue(CIColor(red: color.red, green: color.green, blue: color.blue, alpha: 0), forKey: "inputColor1")

        guard let leak = gradient.outputImage?.cropped(to: image.extent),
              let blend = CIFilter(name: "CIScreenBlendMode") else {
            return image
        }

        blend.setValue(image, forKey: kCIInputImageKey)
        blend.setValue(leak, forKey: kCIInputBackgroundImageKey)

        return blend.outputImage ?? image
    }
}

// MARK: - 调色轮

struct ColorWheelSettings: Codable {
    // 三向调色轮
    var shadows: ColorWheelValue = ColorWheelValue()
    var midtones: ColorWheelValue = ColorWheelValue()
    var highlights: ColorWheelValue = ColorWheelValue()

    // 整体调整
    var temperature: Float = 0  // -100 to 100
    var tint: Float = 0  // -100 to 100
    var vibrance: Float = 0  // -100 to 100
    var saturation: Float = 0  // -100 to 100
}

struct ColorWheelValue: Codable {
    var hue: Float = 0  // 0-360
    var saturation: Float = 0  // 0-100
    var brightness: Float = 0  // -100 to 100
}

class ColorGrading: ObservableObject {
    static let shared = ColorGrading()

    @Published var settings = ColorWheelSettings()

    private init() {}

    // 应用调色
    func apply(to image: CIImage) -> CIImage {
        var result = image

        // 1. 应用色温和色调
        result = applyTemperatureAndTint(result)

        // 2. 分离阴影/中间调/高光并分别调色
        result = applySplitToning(result)

        // 3. 应用饱和度和自然饱和度
        result = applySaturation(result)

        return result
    }

    private func applyTemperatureAndTint(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CITemperatureAndTint") else {
            return image
        }

        // 色温：从蓝色（冷）到黄色（暖）
        let neutral = CIVector(x: 6500, y: 0)  // 中性
        let targetTemp = 6500 + CGFloat(settings.temperature) * 50
        let targetTint = CGFloat(settings.tint)

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(neutral, forKey: "inputNeutral")
        filter.setValue(CIVector(x: targetTemp, y: targetTint), forKey: "inputTargetNeutral")

        return filter.outputImage ?? image
    }

    private func applySplitToning(_ image: CIImage) -> CIImage {
        // 分离调色需要复杂的遮罩操作
        // 简化实现：使用整体色相偏移

        guard let filter = CIFilter(name: "CIHueAdjust") else {
            return image
        }

        let avgHue = (settings.shadows.hue + settings.midtones.hue + settings.highlights.hue) / 3
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(avgHue * Float.pi / 180, forKey: kCIInputAngleKey)

        return filter.outputImage ?? image
    }

    private func applySaturation(_ image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(1.0 + settings.saturation / 100, forKey: kCIInputSaturationKey)

        // 自然饱和度需要更复杂的实现
        // 它只增加低饱和度区域的饱和度

        return filter.outputImage ?? image
    }
}

// MARK: - 故障艺术效果

enum GlitchType: String, CaseIterable, Codable {
    case rgbSplit = "RGB分离"
    case scanlines = "扫描线"
    case noise = "噪波"
    case displacement = "位移"
    case pixelSort = "像素排序"
    case datamosh = "数据损坏"
    case vhs = "VHS"
    case digital = "数字故障"
}

struct GlitchEffect: Codable {
    var type: GlitchType
    var intensity: Float = 0.5
    var speed: Float = 1.0
    var randomSeed: Int = 0
}

class GlitchEffectRenderer: ObservableObject {
    static let shared = GlitchEffectRenderer()

    private init() {}

    // 应用故障效果
    func apply(_ effect: GlitchEffect, to image: CIImage, time: Double) -> CIImage {
        switch effect.type {
        case .rgbSplit:
            return applyRGBSplit(to: image, intensity: effect.intensity, time: time)
        case .scanlines:
            return applyScanlines(to: image, intensity: effect.intensity)
        case .noise:
            return applyNoise(to: image, intensity: effect.intensity, time: time)
        case .displacement:
            return applyDisplacement(to: image, intensity: effect.intensity, time: time)
        case .vhs:
            return applyVHSEffect(to: image, intensity: effect.intensity, time: time)
        case .digital:
            return applyDigitalGlitch(to: image, intensity: effect.intensity, time: time)
        default:
            return image
        }
    }

    private func applyRGBSplit(to image: CIImage, intensity: Float, time: Double) -> CIImage {
        let offset = CGFloat(intensity) * 10 * CGFloat(sin(time * 10))

        // 分离RGB通道
        guard let rFilter = CIFilter(name: "CIColorMatrix"),
              let gFilter = CIFilter(name: "CIColorMatrix"),
              let bFilter = CIFilter(name: "CIColorMatrix") else {
            return image
        }

        // 红色通道
        rFilter.setValue(image.transformed(by: CGAffineTransform(translationX: offset, y: 0)), forKey: kCIInputImageKey)
        rFilter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        rFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        rFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")

        // 绿色通道
        gFilter.setValue(image, forKey: kCIInputImageKey)
        gFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        gFilter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        gFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")

        // 蓝色通道
        bFilter.setValue(image.transformed(by: CGAffineTransform(translationX: -offset, y: 0)), forKey: kCIInputImageKey)
        bFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        bFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        bFilter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")

        guard let r = rFilter.outputImage,
              let g = gFilter.outputImage,
              let b = bFilter.outputImage,
              let add1 = CIFilter(name: "CIAdditionCompositing"),
              let add2 = CIFilter(name: "CIAdditionCompositing") else {
            return image
        }

        add1.setValue(r, forKey: kCIInputImageKey)
        add1.setValue(g, forKey: kCIInputBackgroundImageKey)

        guard let rg = add1.outputImage else { return image }

        add2.setValue(rg, forKey: kCIInputImageKey)
        add2.setValue(b, forKey: kCIInputBackgroundImageKey)

        return add2.outputImage?.cropped(to: image.extent) ?? image
    }

    private func applyScanlines(to image: CIImage, intensity: Float) -> CIImage {
        guard let generator = CIFilter(name: "CIStripesGenerator"),
              let blend = CIFilter(name: "CIMultiplyBlendMode") else {
            return image
        }

        generator.setValue(CIColor.white, forKey: "inputColor0")
        generator.setValue(CIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1), forKey: "inputColor1")
        generator.setValue(2.0, forKey: "inputWidth")

        guard let stripes = generator.outputImage?.cropped(to: image.extent) else {
            return image
        }

        blend.setValue(image, forKey: kCIInputImageKey)
        blend.setValue(stripes, forKey: kCIInputBackgroundImageKey)

        return blend.outputImage ?? image
    }

    private func applyNoise(to image: CIImage, intensity: Float, time: Double) -> CIImage {
        guard let noise = CIFilter(name: "CIRandomGenerator"),
              let blend = CIFilter(name: "CISourceOverCompositing") else {
            return image
        }

        guard var noiseImage = noise.outputImage else { return image }
        noiseImage = noiseImage.cropped(to: image.extent)

        // 调整噪声不透明度
        if let opacity = CIFilter(name: "CIColorMatrix") {
            opacity.setValue(noiseImage, forKey: kCIInputImageKey)
            opacity.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity * 0.3)), forKey: "inputAVector")
            if let output = opacity.outputImage {
                noiseImage = output
            }
        }

        blend.setValue(noiseImage, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)

        return blend.outputImage ?? image
    }

    private func applyDisplacement(to image: CIImage, intensity: Float, time: Double) -> CIImage {
        // 创建位移图
        // 简化实现
        return image
    }

    private func applyVHSEffect(to image: CIImage, intensity: Float, time: Double) -> CIImage {
        var result = image

        // 1. 降低色彩
        if let saturation = CIFilter(name: "CIColorControls") {
            saturation.setValue(result, forKey: kCIInputImageKey)
            saturation.setValue(0.7, forKey: kCIInputSaturationKey)
            if let output = saturation.outputImage {
                result = output
            }
        }

        // 2. 添加扫描线
        result = applyScanlines(to: result, intensity: intensity)

        // 3. 添加噪声
        result = applyNoise(to: result, intensity: intensity * 0.5, time: time)

        // 4. RGB分离
        result = applyRGBSplit(to: result, intensity: intensity * 0.3, time: time)

        return result
    }

    private func applyDigitalGlitch(to image: CIImage, intensity: Float, time: Double) -> CIImage {
        var result = image

        // 随机块状故障
        let blockCount = Int(intensity * 10)

        for _ in 0..<blockCount {
            let y = CGFloat.random(in: 0..<image.extent.height)
            let height = CGFloat.random(in: 5...20)
            let offset = CGFloat.random(in: -50...50) * CGFloat(intensity)

            let blockRect = CGRect(x: 0, y: y, width: image.extent.width, height: height)
            let block = result.cropped(to: blockRect)
                .transformed(by: CGAffineTransform(translationX: offset, y: 0))

            if let blend = CIFilter(name: "CISourceOverCompositing") {
                blend.setValue(block, forKey: kCIInputImageKey)
                blend.setValue(result, forKey: kCIInputBackgroundImageKey)
                if let output = blend.outputImage {
                    result = output.cropped(to: image.extent)
                }
            }
        }

        return result
    }
}

// MARK: - 分身效果

struct CloneEffect: Codable {
    var cloneCount: Int = 3
    var spacing: CGFloat = 0.1  // 间距
    var opacity: Float = 0.7
    var delay: Double = 0.5  // 延迟时间
    var scaleDecay: Float = 0.9  // 缩放衰减
}

class CloneEffectRenderer {
    static let shared = CloneEffectRenderer()

    private var frameBuffer: [CIImage] = []
    private let maxBufferSize = 30

    private init() {}

    // 添加帧到缓冲区
    func addFrame(_ frame: CIImage) {
        frameBuffer.append(frame)
        if frameBuffer.count > maxBufferSize {
            frameBuffer.removeFirst()
        }
    }

    // 渲染分身效果
    func render(currentFrame: CIImage, settings: CloneEffect, frameRate: Double) -> CIImage {
        var result = currentFrame

        let delayFrames = Int(settings.delay * frameRate)

        for i in 1...settings.cloneCount {
            let bufferIndex = frameBuffer.count - 1 - (delayFrames * i)

            if bufferIndex >= 0 && bufferIndex < frameBuffer.count {
                var cloneFrame = frameBuffer[bufferIndex]

                // 应用不透明度
                let opacity = pow(settings.opacity, Float(i))
                if let opacityFilter = CIFilter(name: "CIColorMatrix") {
                    opacityFilter.setValue(cloneFrame, forKey: kCIInputImageKey)
                    opacityFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity)), forKey: "inputAVector")
                    if let output = opacityFilter.outputImage {
                        cloneFrame = output
                    }
                }

                // 应用缩放
                let scale = pow(CGFloat(settings.scaleDecay), CGFloat(i))
                cloneFrame = cloneFrame.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

                // 合成
                if let blend = CIFilter(name: "CISourceOverCompositing") {
                    blend.setValue(result, forKey: kCIInputImageKey)
                    blend.setValue(cloneFrame, forKey: kCIInputBackgroundImageKey)
                    if let output = blend.outputImage {
                        result = output
                    }
                }
            }
        }

        return result
    }

    func clearBuffer() {
        frameBuffer.removeAll()
    }
}

// MARK: - 时间冻结（子弹时间）

struct BulletTimeEffect: Codable {
    var freezeTime: CMTime
    var duration: Double = 2.0
    var rotationAngle: Float = 360  // 旋转角度
    var zoomFactor: Float = 1.5
}

class BulletTimeRenderer {
    static let shared = BulletTimeRenderer()

    private init() {}

    // 生成子弹时间效果
    func render(
        asset: AVAsset,
        effect: BulletTimeEffect,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bullet_time_\(UUID().uuidString).mp4")

        // 1. 提取冻结帧
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw EffectError.noVideoTrack
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        guard let freezeFrame = try? generator.copyCGImage(at: effect.freezeTime, actualTime: nil) else {
            throw EffectError.frameExtractionFailed
        }

        // 2. 生成旋转/缩放动画帧
        let frameRate: Double = 30
        let totalFrames = Int(effect.duration * frameRate)

        for frameIndex in 0..<totalFrames {
            let t = Double(frameIndex) / Double(totalFrames)

            // 计算当前旋转角度和缩放
            let currentRotation = CGFloat(effect.rotationAngle) * CGFloat(t) * .pi / 180
            let currentZoom = 1.0 + (CGFloat(effect.zoomFactor) - 1.0) * CGFloat(sin(t * .pi))

            // 应用变换
            // 写入帧

            progress(t)
        }

        return outputURL
    }
}

// MARK: - 缩放转场

struct ZoomTransitionEffect: Codable {
    var zoomPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var maxZoom: Float = 10
    var duration: Double = 1.0
    var easing: EasingFunction = .easeInOut
}

class ZoomTransitionRenderer {
    static let shared = ZoomTransitionRenderer()

    private init() {}

    // 渲染缩放转场
    func render(
        from clip1: Clip,
        to clip2: Clip,
        effect: ZoomTransitionEffect
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zoom_transition_\(UUID().uuidString).mp4")

        // 1. 从第一个片段放大到黑屏
        // 2. 从第二个片段缩小出来

        return outputURL
    }
}

// MARK: - 老电影效果

struct VintageFilmEffect: Codable {
    var grain: Float = 0.3
    var scratches: Float = 0.2
    var dust: Float = 0.1
    var vignette: Float = 0.4
    var flickering: Float = 0.1
    var colorFade: Float = 0.3
    var jitter: Float = 0.05
}

class VintageFilmRenderer {
    static let shared = VintageFilmRenderer()

    private init() {}

    func apply(_ effect: VintageFilmEffect, to image: CIImage, time: Double) -> CIImage {
        var result = image

        // 1. 褪色效果
        if effect.colorFade > 0 {
            if let sepia = CIFilter(name: "CISepiaTone") {
                sepia.setValue(result, forKey: kCIInputImageKey)
                sepia.setValue(effect.colorFade, forKey: kCIInputIntensityKey)
                if let output = sepia.outputImage {
                    result = output
                }
            }
        }

        // 2. 胶片颗粒
        if effect.grain > 0 {
            result = GlitchEffectRenderer.shared.apply(
                GlitchEffect(type: .noise, intensity: effect.grain),
                to: result,
                time: time
            )
        }

        // 3. 暗角
        if effect.vignette > 0 {
            if let vignette = CIFilter(name: "CIVignette") {
                vignette.setValue(result, forKey: kCIInputImageKey)
                vignette.setValue(effect.vignette * 2, forKey: kCIInputIntensityKey)
                vignette.setValue(1.0, forKey: kCIInputRadiusKey)
                if let output = vignette.outputImage {
                    result = output
                }
            }
        }

        // 4. 闪烁效果
        if effect.flickering > 0 {
            let flicker = 1.0 - effect.flickering * Float.random(in: 0...0.3)
            if let brightness = CIFilter(name: "CIColorControls") {
                brightness.setValue(result, forKey: kCIInputImageKey)
                brightness.setValue(flicker, forKey: kCIInputBrightnessKey)
                if let output = brightness.outputImage {
                    result = output
                }
            }
        }

        return result
    }
}

// MARK: - 错误类型

enum EffectError: Error {
    case noVideoTrack
    case frameExtractionFailed
    case renderingFailed
}

// 需要导入 UIKit 以使用 UIGraphicsImageRenderer
#if canImport(UIKit)
import UIKit
#endif
