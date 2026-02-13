import Foundation
import AVFoundation
import CoreImage

/// 滤镜效果模型
struct VideoFilter: Identifiable, Equatable {
    let id: UUID
    var type: FilterType
    var intensity: Float  // 0.0 - 1.0

    /// 自定义参数
    var parameters: FilterParameters

    init(
        id: UUID = UUID(),
        type: FilterType = .none,
        intensity: Float = 1.0,
        parameters: FilterParameters = FilterParameters()
    ) {
        self.id = id
        self.type = type
        self.intensity = intensity
        self.parameters = parameters
    }

    static func == (lhs: VideoFilter, rhs: VideoFilter) -> Bool {
        lhs.id == rhs.id
    }

    /// 获取 CIFilter
    func makeCIFilter() -> CIFilter? {
        type.makeCIFilter(intensity: intensity, parameters: parameters)
    }
}

/// 滤镜参数
struct FilterParameters: Equatable {
    // 基础调整
    var brightness: Float = 0       // -1.0 to 1.0
    var contrast: Float = 1.0       // 0.0 to 4.0
    var saturation: Float = 1.0     // 0.0 to 2.0
    var exposure: Float = 0         // -2.0 to 2.0

    // 色温色调
    var temperature: Float = 6500   // 2000 to 10000 Kelvin
    var tint: Float = 0             // -150 to 150

    // 高级调整
    var highlights: Float = 1.0     // 0.0 to 2.0
    var shadows: Float = 0          // -1.0 to 1.0
    var vibrance: Float = 0         // -1.0 to 1.0
    var sharpness: Float = 0        // 0.0 to 2.0
    var vignette: Float = 0         // 0.0 to 2.0
    var grain: Float = 0            // 0.0 to 1.0
}

/// 滤镜类型
enum FilterType: String, CaseIterable, Codable {
    // 无滤镜
    case none = "原片"

    // 预设滤镜
    case vivid = "鲜艳"
    case dramatic = "戏剧"
    case mono = "单色"
    case noir = "黑白电影"
    case silvertone = "银色调"
    case vintage = "复古"
    case warm = "暖色"
    case cool = "冷色"
    case fade = "褪色"
    case chrome = "铬黄"
    case process = "冲印"
    case transfer = "转印"
    case instant = "即时"

    // 调整类
    case colorAdjust = "色彩调整"

    var icon: String {
        switch self {
        case .none: return "circle"
        case .vivid: return "sun.max"
        case .dramatic: return "theatermasks"
        case .mono: return "circle.lefthalf.filled"
        case .noir: return "film"
        case .silvertone: return "moon"
        case .vintage: return "clock.arrow.circlepath"
        case .warm: return "flame"
        case .cool: return "snowflake"
        case .fade: return "cloud"
        case .chrome: return "sparkles"
        case .process: return "photo"
        case .transfer: return "doc.on.doc"
        case .instant: return "camera"
        case .colorAdjust: return "slider.horizontal.3"
        }
    }

    var displayName: String { rawValue }

    /// 创建对应的 CIFilter
    func makeCIFilter(intensity: Float, parameters: FilterParameters) -> CIFilter? {
        switch self {
        case .none:
            return nil

        case .vivid:
            let filter = CIFilter(name: "CIVibrance")
            filter?.setValue(0.5 * intensity, forKey: "inputAmount")
            return filter

        case .dramatic:
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(1.3 * intensity, forKey: kCIInputContrastKey)
            filter?.setValue(1.1 * intensity, forKey: kCIInputSaturationKey)
            return filter

        case .mono:
            return CIFilter(name: "CIPhotoEffectMono")

        case .noir:
            return CIFilter(name: "CIPhotoEffectNoir")

        case .silvertone:
            return CIFilter(name: "CIPhotoEffectTonal")

        case .vintage:
            return CIFilter(name: "CIPhotoEffectInstant")

        case .warm:
            let filter = CIFilter(name: "CITemperatureAndTint")
            filter?.setValue(CIVector(x: 7000, y: 0), forKey: "inputNeutral")
            filter?.setValue(CIVector(x: 7500 + CGFloat(500 * intensity), y: 0), forKey: "inputTargetNeutral")
            return filter

        case .cool:
            let filter = CIFilter(name: "CITemperatureAndTint")
            filter?.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filter?.setValue(CIVector(x: 5500 - CGFloat(500 * intensity), y: 0), forKey: "inputTargetNeutral")
            return filter

        case .fade:
            let filter = CIFilter(name: "CIPhotoEffectFade")
            return filter

        case .chrome:
            return CIFilter(name: "CIPhotoEffectChrome")

        case .process:
            return CIFilter(name: "CIPhotoEffectProcess")

        case .transfer:
            return CIFilter(name: "CIPhotoEffectTransfer")

        case .instant:
            return CIFilter(name: "CIPhotoEffectInstant")

        case .colorAdjust:
            // 自定义色彩调整需要链式滤镜
            return nil
        }
    }
}

/// 滤镜处理器
class FilterProcessor {
    private let context: CIContext

    init() {
        // 使用 Metal 加速
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: metalDevice)
        } else {
            context = CIContext()
        }
    }

    /// 应用滤镜到图像
    func apply(filter: VideoFilter, to image: CIImage) -> CIImage {
        var outputImage = image

        // 先应用预设滤镜
        if let ciFilter = filter.makeCIFilter() {
            ciFilter.setValue(outputImage, forKey: kCIInputImageKey)
            if let result = ciFilter.outputImage {
                outputImage = result
            }
        }

        // 应用自定义调整
        outputImage = applyColorAdjustments(to: outputImage, parameters: filter.parameters)

        return outputImage
    }

    /// 应用色彩调整
    private func applyColorAdjustments(to image: CIImage, parameters: FilterParameters) -> CIImage {
        var outputImage = image

        // 亮度、对比度、饱和度
        if parameters.brightness != 0 || parameters.contrast != 1.0 || parameters.saturation != 1.0 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(parameters.brightness, forKey: kCIInputBrightnessKey)
                filter.setValue(parameters.contrast, forKey: kCIInputContrastKey)
                filter.setValue(parameters.saturation, forKey: kCIInputSaturationKey)
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // 曝光
        if parameters.exposure != 0 {
            if let filter = CIFilter(name: "CIExposureAdjust") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(parameters.exposure, forKey: kCIInputEVKey)
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // 色温
        if parameters.temperature != 6500 || parameters.tint != 0 {
            if let filter = CIFilter(name: "CITemperatureAndTint") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                filter.setValue(CIVector(x: CGFloat(parameters.temperature), y: CGFloat(parameters.tint)), forKey: "inputTargetNeutral")
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // 高光和阴影
        if parameters.highlights != 1.0 || parameters.shadows != 0 {
            if let filter = CIFilter(name: "CIHighlightShadowAdjust") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(parameters.highlights, forKey: "inputHighlightAmount")
                filter.setValue(parameters.shadows, forKey: "inputShadowAmount")
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // 自然饱和度
        if parameters.vibrance != 0 {
            if let filter = CIFilter(name: "CIVibrance") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(parameters.vibrance, forKey: "inputAmount")
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // 锐化
        if parameters.sharpness > 0 {
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(parameters.sharpness, forKey: kCIInputSharpnessKey)
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // 暗角
        if parameters.vignette > 0 {
            if let filter = CIFilter(name: "CIVignette") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(parameters.vignette, forKey: kCIInputIntensityKey)
                filter.setValue(1.0, forKey: kCIInputRadiusKey)
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        return outputImage
    }

    /// 生成缩略图预览
    func generatePreview(filter: VideoFilter, from sourceImage: CGImage, size: CGSize) -> CGImage? {
        let ciImage = CIImage(cgImage: sourceImage)
        let filteredImage = apply(filter: filter, to: ciImage)

        return context.createCGImage(filteredImage, from: filteredImage.extent)
    }
}

/// 用于视频合成的自定义滤镜 Compositor
class FilteredCompositor: NSObject, AVVideoCompositing {
    private let filterProcessor = FilterProcessor()
    private var filter: VideoFilter?

    var sourcePixelBufferAttributes: [String: Any]? {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }

    func setFilter(_ filter: VideoFilter) {
        self.filter = filter
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // 渲染上下文改变时的处理
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let filter = filter,
              filter.type != .none,
              let sourceBuffer = request.sourceFrame(byTrackID: request.sourceTrackIDs.first?.int32Value ?? 0) else {
            // 无滤镜时直接返回原帧
            if let sourceBuffer = request.sourceFrame(byTrackID: request.sourceTrackIDs.first?.int32Value ?? 0) {
                request.finish(withComposedVideoFrame: sourceBuffer)
            } else {
                request.finish(with: NSError(domain: "FilteredCompositor", code: -1))
            }
            return
        }

        // 创建 CIImage
        let ciImage = CIImage(cvPixelBuffer: sourceBuffer)

        // 应用滤镜
        let filteredImage = filterProcessor.apply(filter: filter, to: ciImage)

        // 获取输出 buffer
        guard let outputBuffer = request.renderContext.newPixelBuffer() else {
            request.finish(with: NSError(domain: "FilteredCompositor", code: -2))
            return
        }

        // 渲染到输出 buffer
        let context = CIContext()
        context.render(filteredImage, to: outputBuffer)

        request.finish(withComposedVideoFrame: outputBuffer)
    }

    func cancelAllPendingVideoCompositionRequests() {
        // 取消所有待处理请求
    }
}
