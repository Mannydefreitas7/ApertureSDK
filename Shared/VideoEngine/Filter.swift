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

/// Filter parameters
struct FilterParameters: Equatable {
    // Basic adjustments
    var brightness: Float = 0       // -1.0 to 1.0
    var contrast: Float = 1.0       // 0.0 to 4.0
    var saturation: Float = 1.0     // 0.0 to 2.0
    var exposure: Float = 0         // -2.0 to 2.0

    // Temperature and tint
    var temperature: Float = 6500   // 2000 to 10000 Kelvin
    var tint: Float = 0             // -150 to 150

    // Advanced adjustments
    var highlights: Float = 1.0     // 0.0 to 2.0
    var shadows: Float = 0          // -1.0 to 1.0
    var vibrance: Float = 0         // -1.0 to 1.0
    var sharpness: Float = 0        // 0.0 to 2.0
    var vignette: Float = 0         // 0.0 to 2.0
    var grain: Float = 0            // 0.0 to 1.0
}

/// Filter type
enum FilterType: String, CaseIterable, Codable {
    // No filter
    case none = "Original"

    // Preset filters
    case vivid = "Vivid"
    case dramatic = "Dramatic"
    case mono = "Mono"
    case noir = "Noir"
    case silvertone = "Silver Tone"
    case vintage = "Vintage"
    case warm = "Warm"
    case cool = "Cool"
    case fade = "Fade"
    case chrome = "Chrome"
    case process = "Process"
    case transfer = "Transfer"
    case instant = "Instant"

    // Adjustment class
    case colorAdjust = "Color Adjust"

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

    /// Create corresponding CIFilter
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
            // Custom color adjustments require filter chains
            return nil
        }
    }
}

/// Filter processor
class FilterProcessor {
    private let context: CIContext

    init() {
        // Use Metal acceleration
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: metalDevice)
        } else {
            context = CIContext()
        }
    }

    /// Apply filter to image
    func apply(filter: VideoFilter, to image: CIImage) -> CIImage {
        var outputImage = image

        // First apply preset filter
        if let ciFilter = filter.makeCIFilter() {
            ciFilter.setValue(outputImage, forKey: kCIInputImageKey)
            if let result = ciFilter.outputImage {
                outputImage = result
            }
        }

        // Apply custom adjustments
        outputImage = applyColorAdjustments(to: outputImage, parameters: filter.parameters)

        return outputImage
    }

    /// Apply color adjustments
    private func applyColorAdjustments(to image: CIImage, parameters: FilterParameters) -> CIImage {
        var outputImage = image

        // Brightness, contrast, saturation
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

        // Exposure
        if parameters.exposure != 0 {
            if let filter = CIFilter(name: "CIExposureAdjust") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(parameters.exposure, forKey: kCIInputEVKey)
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // Temperature
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

        // Highlights and shadows
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

        // Vibrance
        if parameters.vibrance != 0 {
            if let filter = CIFilter(name: "CIVibrance") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(parameters.vibrance, forKey: "inputAmount")
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // Sharpness
        if parameters.sharpness > 0 {
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(outputImage, forKey: kCIInputImageKey)
                filter.setValue(parameters.sharpness, forKey: kCIInputSharpnessKey)
                if let result = filter.outputImage {
                    outputImage = result
                }
            }
        }

        // Vignette
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

    /// Generate thumbnail preview
    func generatePreview(filter: VideoFilter, from sourceImage: CGImage, size: CGSize) -> CGImage? {
        let ciImage = CIImage(cgImage: sourceImage)
        let filteredImage = apply(filter: filter, to: ciImage)

        return context.createCGImage(filteredImage, from: filteredImage.extent)
    }
}

/// Custom filter compositor for video composition
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
        // Handle render context changes
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let filter = filter,
              filter.type != .none,
              let sourceBuffer = request.sourceFrame(byTrackID: request.sourceTrackIDs.first?.int32Value ?? 0) else {
            // Return original frame when no filter applied
            if let sourceBuffer = request.sourceFrame(byTrackID: request.sourceTrackIDs.first?.int32Value ?? 0) {
                request.finish(withComposedVideoFrame: sourceBuffer)
            } else {
                request.finish(with: NSError(domain: "FilteredCompositor", code: -1))
            }
            return
        }

        // Create CIImage
        let ciImage = CIImage(cvPixelBuffer: sourceBuffer)

        // Apply filter
        let filteredImage = filterProcessor.apply(filter: filter, to: ciImage)

        // Get output buffer
        guard let outputBuffer = request.renderContext.newPixelBuffer() else {
            request.finish(with: NSError(domain: "FilteredCompositor", code: -2))
            return
        }

        // Render to output buffer
        let context = CIContext()
        context.render(filteredImage, to: outputBuffer)

        request.finish(withComposedVideoFrame: outputBuffer)
    }

    func cancelAllPendingVideoCompositionRequests() {
        // Cancel all pending requests
    }
}
