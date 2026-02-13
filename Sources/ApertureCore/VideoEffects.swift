import Foundation
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - 画中画

/// 画中画配置
struct PictureInPicture: Identifiable, Equatable {
    let id: UUID
    var overlayClipId: UUID  // 叠加的片段

    /// 位置（归一化 0-1）
    var position: CGPoint = CGPoint(x: 0.8, y: 0.2)

    /// 大小（相对于画面）
    var scale: CGFloat = 0.3

    /// 边框
    var borderWidth: CGFloat = 2
    var borderColor: CodableColor = CodableColor(.white)

    /// 圆角
    var cornerRadius: CGFloat = 8

    /// 阴影
    var shadowEnabled: Bool = true
    var shadowColor: CodableColor = CodableColor(.black.withAlphaComponent(0.5))
    var shadowOffset: CGSize = CGSize(width: 4, height: 4)
    var shadowRadius: CGFloat = 8

    /// 时间范围
    var timeRange: CMTimeRange

    init(
        id: UUID = UUID(),
        overlayClipId: UUID,
        timeRange: CMTimeRange
    ) {
        self.id = id
        self.overlayClipId = overlayClipId
        self.timeRange = timeRange
    }
}

/// 画中画位置预设
enum PiPPosition: String, CaseIterable {


    var normalizedPosition: CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: 0.2, y: 0.8)
        case .topRight: return CGPoint(x: 0.8, y: 0.8)
        case .bottomLeft: return CGPoint(x: 0.2, y: 0.2)
        case .bottomRight: return CGPoint(x: 0.8, y: 0.2)
        case .center: return CGPoint(x: 0.5, y: 0.5)
        case .custom: return CGPoint(x: 0.5, y: 0.5)
        }
    }

    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center
    case custom

    var icon: String {
        switch self {
        case .topLeft: return "rectangle.inset.topleft.filled"
        case .topRight: return "rectangle.inset.topright.filled"
        case .bottomLeft: return "rectangle.inset.bottomleft.filled"
        case .bottomRight: return "rectangle.inset.bottomright.filled"
        case .center: return "rectangle.center.inset.filled"
            case .custom: return "rectangle.3d.inverted"

        }
    }
}

// MARK: - 绿幕/色度键

/// 色度键（绿幕）效果
struct ChromaKey: Identifiable, Equatable {
    let id: UUID

    /// 要移除的颜色
    var keyColor: CodableColor = CodableColor(.green)

    /// 颜色容差
    var tolerance: Float = 0.4

    /// 边缘柔和度
    var softness: Float = 0.1

    /// 溢色抑制
    var spillSuppression: Float = 0.5

    /// 是否启用
    var isEnabled: Bool = true

    init(id: UUID = UUID()) {
        self.id = id
    }

    /// 创建 CIFilter
    func makeCIFilter() -> CIFilter? {
        // 使用 CIColorCube 实现色度键
        let filter = CIFilter(name: "CIColorCube")

        // 创建颜色查找表
        let size = 64
        var cubeData = [Float](repeating: 0, count: size * size * size * 4)

        let keyR = Float(keyColor.red)
        let keyG = Float(keyColor.green)
        let keyB = Float(keyColor.blue)

        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let index = (b * size * size + g * size + r) * 4

                    let rf = Float(r) / Float(size - 1)
                    let gf = Float(g) / Float(size - 1)
                    let bf = Float(b) / Float(size - 1)

                    // 计算与键色的距离
                    let distance = sqrt(
                        pow(rf - keyR, 2) +
                        pow(gf - keyG, 2) +
                        pow(bf - keyB, 2)
                    )

                    // 计算 alpha
                    var alpha: Float
                    if distance < tolerance {
                        alpha = 0
                    } else if distance < tolerance + softness {
                        alpha = (distance - tolerance) / softness
                    } else {
                        alpha = 1
                    }

                    // 预乘 alpha
                    cubeData[index] = rf * alpha
                    cubeData[index + 1] = gf * alpha
                    cubeData[index + 2] = bf * alpha
                    cubeData[index + 3] = alpha
                }
            }
        }

        let data = Data(bytes: cubeData, count: cubeData.count * MemoryLayout<Float>.size)
        filter?.setValue(size, forKey: "inputCubeDimension")
        filter?.setValue(data, forKey: "inputCubeData")

        return filter
    }
}

// MARK: - 模糊效果

/// 模糊效果
struct BlurEffect: Identifiable, Equatable {
    let id: UUID
    var type: BlurType = .gaussian
    var radius: CGFloat = 10
    var region: BlurRegion = .fullFrame
    var isAnimated: Bool = false

    init(id: UUID = UUID()) {
        self.id = id
    }

    /// 模糊类型
    enum BlurType: String, CaseIterable {
        case gaussian = "高斯模糊"
        case motion = "运动模糊"
        case zoom = "缩放模糊"
        case box = "方框模糊"
        case disc = "圆盘模糊"

        func makeCIFilter(radius: CGFloat) -> CIFilter? {
            switch self {
            case .gaussian:
                let filter = CIFilter.gaussianBlur()
                filter.radius = Float(radius)
                return filter
            case .motion:
                let filter = CIFilter.motionBlur()
                filter.radius = Float(radius)
                filter.angle = 0
                return filter
            case .zoom:
                let filter = CIFilter.zoomBlur()
                filter.amount = Float(radius)
                return filter
            case .box:
                let filter = CIFilter.boxBlur()
                filter.radius = Float(radius)
                return filter
            case .disc:
                let filter = CIFilter.discBlur()
                filter.radius = Float(radius)
                return filter
            }
        }
    }

    /// 模糊区域
    enum BlurRegion: Equatable {
        case fullFrame           // 全画面
        case rectangle(CGRect)   // 矩形区域
        case circle(center: CGPoint, radius: CGFloat)  // 圆形区域
        case faceTracking        // 人脸追踪
        case custom(mask: String) // 自定义蒙版
    }
}

/// 马赛克效果
struct MosaicEffect: Identifiable, Equatable {
    let id: UUID
    var blockSize: CGFloat = 20
    var region: BlurEffect.BlurRegion = .fullFrame
    var shape: MosaicShape = .square

    init(id: UUID = UUID()) {
        self.id = id
    }

    enum MosaicShape: String, CaseIterable {
        case square = "方形"
        case hexagon = "六边形"
        case circle = "圆形"
    }

    func makeCIFilter() -> CIFilter? {
        let filter = CIFilter.pixellate()
        filter.scale = Float(blockSize)
        return filter
    }
}

// MARK: - 速度曲线

/// 速度曲线
struct SpeedCurve: Identifiable, Equatable {
    let id: UUID
    var keyframes: [SpeedKeyframe] = []

    init(id: UUID = UUID()) {
        self.id = id
    }

    /// 速度关键帧
    struct SpeedKeyframe: Identifiable, Equatable {
        let id: UUID
        var time: CGFloat  // 归一化时间 0-1
        var speed: CGFloat // 速度倍率

        init(id: UUID = UUID(), time: CGFloat, speed: CGFloat) {
            self.id = id
            self.time = time
            self.speed = speed
        }
    }

    /// 预设速度曲线
    enum Preset: String, CaseIterable {
        case normal = "正常"
        case slowMotion = "慢动作"
        case fastMotion = "快动作"
        case rampUp = "加速"
        case rampDown = "减速"
        case pulse = "脉冲"
        case reverse = "倒放"

        func apply(to curve: inout SpeedCurve) {
            curve.keyframes.removeAll()

            switch self {
            case .normal:
                curve.keyframes = [
                    SpeedKeyframe(time: 0, speed: 1),
                    SpeedKeyframe(time: 1, speed: 1)
                ]
            case .slowMotion:
                curve.keyframes = [
                    SpeedKeyframe(time: 0, speed: 0.5),
                    SpeedKeyframe(time: 1, speed: 0.5)
                ]
            case .fastMotion:
                curve.keyframes = [
                    SpeedKeyframe(time: 0, speed: 2),
                    SpeedKeyframe(time: 1, speed: 2)
                ]
            case .rampUp:
                curve.keyframes = [
                    SpeedKeyframe(time: 0, speed: 0.5),
                    SpeedKeyframe(time: 1, speed: 2)
                ]
            case .rampDown:
                curve.keyframes = [
                    SpeedKeyframe(time: 0, speed: 2),
                    SpeedKeyframe(time: 1, speed: 0.5)
                ]
            case .pulse:
                curve.keyframes = [
                    SpeedKeyframe(time: 0, speed: 1),
                    SpeedKeyframe(time: 0.25, speed: 0.3),
                    SpeedKeyframe(time: 0.5, speed: 1),
                    SpeedKeyframe(time: 0.75, speed: 0.3),
                    SpeedKeyframe(time: 1, speed: 1)
                ]
            case .reverse:
                curve.keyframes = [
                    SpeedKeyframe(time: 0, speed: -1),
                    SpeedKeyframe(time: 1, speed: -1)
                ]
            }
        }
    }

    /// 获取指定进度的速度
    func speed(at progress: CGFloat) -> CGFloat {
        guard !keyframes.isEmpty else { return 1 }
        guard keyframes.count > 1 else { return keyframes[0].speed }

        let sorted = keyframes.sorted { $0.time < $1.time }

        // 查找前后关键帧
        var prev = sorted[0]
        var next = sorted[sorted.count - 1]

        for i in 0..<sorted.count - 1 {
            if sorted[i].time <= progress && sorted[i + 1].time >= progress {
                prev = sorted[i]
                next = sorted[i + 1]
                break
            }
        }

        // 线性插值
        if next.time == prev.time { return prev.speed }

        let t = (progress - prev.time) / (next.time - prev.time)
        return prev.speed + (next.speed - prev.speed) * t
    }
}

// MARK: - 分屏效果

/// 分屏效果
struct SplitScreen: Identifiable, Equatable {
    let id: UUID
    var layout: SplitLayout
    var clips: [UUID]  // 参与分屏的片段 ID
    var borderWidth: CGFloat = 2
    var borderColor: CodableColor = CodableColor(.white)

    init(id: UUID = UUID(), layout: SplitLayout, clips: [UUID]) {
        self.id = id
        self.layout = layout
        self.clips = clips
    }

    /// 分屏布局
    enum SplitLayout: String, CaseIterable {
        case horizontal2 = "左右分屏"
        case vertical2 = "上下分屏"
        case grid4 = "四宫格"
        case grid9 = "九宫格"
        case pip = "画中画"
        case diagonal = "斜分屏"

        var clipCount: Int {
            switch self {
            case .horizontal2, .vertical2, .pip, .diagonal: return 2
            case .grid4: return 4
            case .grid9: return 9
            }
        }

        /// 获取每个片段的区域
        func regions(in size: CGSize) -> [CGRect] {
            switch self {
            case .horizontal2:
                return [
                    CGRect(x: 0, y: 0, width: size.width / 2, height: size.height),
                    CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height)
                ]
            case .vertical2:
                return [
                    CGRect(x: 0, y: size.height / 2, width: size.width, height: size.height / 2),
                    CGRect(x: 0, y: 0, width: size.width, height: size.height / 2)
                ]
            case .grid4:
                let w = size.width / 2
                let h = size.height / 2
                return [
                    CGRect(x: 0, y: h, width: w, height: h),
                    CGRect(x: w, y: h, width: w, height: h),
                    CGRect(x: 0, y: 0, width: w, height: h),
                    CGRect(x: w, y: 0, width: w, height: h)
                ]
            case .grid9:
                let w = size.width / 3
                let h = size.height / 3
                var regions: [CGRect] = []
                for row in 0..<3 {
                    for col in 0..<3 {
                        regions.append(CGRect(x: CGFloat(col) * w, y: CGFloat(2 - row) * h, width: w, height: h))
                    }
                }
                return regions
            case .pip:
                return [
                    CGRect(origin: .zero, size: size),
                    CGRect(x: size.width * 0.65, y: size.height * 0.05, width: size.width * 0.3, height: size.height * 0.3)
                ]
            case .diagonal:
                return [
                    CGRect(origin: .zero, size: size),
                    CGRect(origin: .zero, size: size)
                ]
            }
        }
    }
}

// MARK: - LUT (查找表)

/// LUT 调色
struct LUTFilter: Identifiable, Equatable {
    let id: UUID
    var name: String
    var intensity: Float = 1.0
    var lutData: Data?

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    /// 内置 LUT 预设
    enum Preset: String, CaseIterable {
        case cinematic = "电影感"
        case vintage = "复古胶片"
        case teal_orange = "青橙"
        case bleach = "漂白"
        case noir = "黑色电影"
        case vibrant = "鲜艳"
        case muted = "柔和"
        case warm_sunset = "暖色日落"
        case cool_morning = "冷色清晨"
        case cyberpunk = "赛博朋克"

        var displayName: String { rawValue }
    }

    /// 从文件加载 LUT
    static func load(from url: URL) throws -> LUTFilter {
        let data = try Data(contentsOf: url)
        var lut = LUTFilter(name: url.deletingPathExtension().lastPathComponent)
        lut.lutData = data
        return lut
    }

    /// 创建 CIFilter
    func makeCIFilter() -> CIFilter? {
        guard let data = lutData else { return nil }

        let filter = CIFilter(name: "CIColorCubeWithColorSpace")
        filter?.setValue(64, forKey: "inputCubeDimension")
        filter?.setValue(data, forKey: "inputCubeData")
        filter?.setValue(CGColorSpace(name: CGColorSpace.sRGB), forKey: "inputColorSpace")

        return filter
    }
}

// MARK: - 画面稳定

/// 画面稳定配置
struct VideoStabilization: Equatable {
    var isEnabled: Bool = true
    var strength: Float = 0.5  // 0-1
    var smoothness: Float = 0.5
    var cropRatio: Float = 0.1  // 裁剪比例

    /// 稳定模式
    enum Mode: String, CaseIterable {
        case standard = "标准"
        case cinematic = "电影级"
        case auto = "自动"
    }

    var mode: Mode = .standard
}

// MARK: - 镜头校正

/// 镜头畸变校正
struct LensCorrection: Equatable {
    var isEnabled: Bool = false

    /// 桶形/枕形畸变 (-1 to 1)
    var distortion: Float = 0

    /// 色差校正
    var chromaticAberration: Float = 0

    /// 暗角校正
    var vignetteCorrection: Float = 0

    /// 预设镜头配置
    enum LensPreset: String, CaseIterable {
        case none = "无"
        case gopro_wide = "GoPro 广角"
        case iphone_wide = "iPhone 广角"
        case iphone_ultra = "iPhone 超广角"
        case dji_mavic = "DJI Mavic"
        case custom = "自定义"
    }

    var preset: LensPreset = .none

    mutating func applyPreset(_ preset: LensPreset) {
        self.preset = preset
        switch preset {
        case .none:
            distortion = 0
            chromaticAberration = 0
            vignetteCorrection = 0
        case .gopro_wide:
            distortion = -0.3
            chromaticAberration = 0.1
            vignetteCorrection = 0.2
        case .iphone_wide:
            distortion = -0.1
            chromaticAberration = 0.05
            vignetteCorrection = 0.1
        case .iphone_ultra:
            distortion = -0.4
            chromaticAberration = 0.15
            vignetteCorrection = 0.3
        case .dji_mavic:
            distortion = -0.2
            chromaticAberration = 0.08
            vignetteCorrection = 0.15
        case .custom:
            break
        }
    }
}

// MARK: - 视频效果处理器

/// 视频效果处理器
class VideoEffectProcessor {
    private let context: CIContext

    init() {
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device)
        } else {
            context = CIContext()
        }
    }

    /// 应用色度键（绿幕）
    func applyChromaKey(_ chromaKey: ChromaKey, to image: CIImage) -> CIImage {
        guard chromaKey.isEnabled,
              let filter = chromaKey.makeCIFilter() else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage ?? image
    }

    /// 应用模糊效果
    func applyBlur(_ blur: BlurEffect, to image: CIImage) -> CIImage {
        guard let filter = blur.type.makeCIFilter(radius: blur.radius) else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)

        guard let blurredImage = filter.outputImage else {
            return image
        }

        // 如果是区域模糊，需要合成
        switch blur.region {
        case .fullFrame:
            return blurredImage

        case .rectangle(let rect):
            return compositeBlur(original: image, blurred: blurredImage, mask: rectangleMask(rect, size: image.extent.size))

        case .circle(let center, let radius):
            return compositeBlur(original: image, blurred: blurredImage, mask: circleMask(center: center, radius: radius, size: image.extent.size))

        default:
            return blurredImage
        }
    }

    /// 创建矩形蒙版
    private func rectangleMask(_ rect: CGRect, size: CGSize) -> CIImage {
        let color = CIColor(red: 1, green: 1, blue: 1)
        let colorImage = CIImage(color: color).cropped(to: CGRect(origin: .zero, size: size))

        // 创建白色矩形
        let whiteRect = CIImage(color: color).cropped(to: rect)

        // 在黑色背景上放置白色矩形
        let blackImage = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))

        let compositeFilter = CIFilter.sourceOverCompositing()
        compositeFilter.inputImage = whiteRect
        compositeFilter.backgroundImage = blackImage

        return compositeFilter.outputImage ?? blackImage
    }

    /// 创建圆形蒙版
    private func circleMask(center: CGPoint, radius: CGFloat, size: CGSize) -> CIImage {
        let filter = CIFilter.radialGradient()
        filter.center = center
        filter.radius0 = Float(radius * 0.8)
        filter.radius1 = Float(radius)
        filter.color0 = CIColor.white
        filter.color1 = CIColor.black

        return filter.outputImage?.cropped(to: CGRect(origin: .zero, size: size)) ?? CIImage()
    }

    /// 合成模糊
    private func compositeBlur(original: CIImage, blurred: CIImage, mask: CIImage) -> CIImage {
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = blurred
        blendFilter.backgroundImage = original
        blendFilter.maskImage = mask

        return blendFilter.outputImage ?? original
    }

    /// 应用马赛克
    func applyMosaic(_ mosaic: MosaicEffect, to image: CIImage) -> CIImage {
        guard let filter = mosaic.makeCIFilter() else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage ?? image
    }
}
