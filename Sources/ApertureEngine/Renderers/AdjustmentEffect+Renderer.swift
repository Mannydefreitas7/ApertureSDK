#if canImport(AVFoundation)
import Foundation
import CoreImage
import ApertureCore

/// Renders effects defined in Core models using CoreImage filters
public actor EffectRenderer {

    static let shared = EffectRenderer()

    private let ciContext: CIContext
    
    public init(ciContext: CIContext = CIContext()) {
        self.ciContext = ciContext
    }
    
    /// Apply a list of effects to a CIImage
    public func apply(effects: [Effect], to image: CIImage) -> CIImage {
        var result = image
        for effect in effects where effect.isEnabled {
            result = apply(effect: effect, to: result)
        }
        return result
    }
    
    /// Apply a single effect to a CIImage
    public func apply(effect: Effect, to image: CIImage) -> CIImage {
        switch effect.type {
        case .sepia:
            return applySepia(to: image, intensity: effect.parameters["intensity"] ?? 0.8)
        case .blackAndWhite:
            return applyBlackAndWhite(to: image)
        case .brightness:
            return applyColorControls(to: image, brightness: effect.parameters["value"] ?? 0, contrast: 1, saturation: 1)
        case .contrast:
            return applyColorControls(to: image, brightness: 0, contrast: effect.parameters["value"] ?? 1, saturation: 1)
        case .saturation:
            return applyColorControls(to: image, brightness: 0, contrast: 1, saturation: effect.parameters["value"] ?? 1)
        case .blur:
            return applyBlur(to: image, radius: effect.parameters["radius"] ?? 10)
        case .sharpen:
            return applySharpen(to: image, intensity: effect.parameters["intensity"] ?? 0.5)
        case .vignette:
            return applyVignette(to: image, intensity: effect.parameters["intensity"] ?? 1.0, radius: effect.parameters["radius"] ?? 1.0)
        case .colorControls:
            return applyColorControls(
                to: image,
                brightness: effect.parameters["brightness"] ?? 0,
                contrast: effect.parameters["contrast"] ?? 1,
                saturation: effect.parameters["saturation"] ?? 1
            )
        case .customLUT:
            return image // LUT support via VideoEditorAssets
        }
    }
    
    // MARK: - Private Filter Implementations
    
    private func applySepia(to image: CIImage, intensity: Double) -> CIImage {
        guard let filter = CIFilter(name: "CISepiaTone") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value: intensity), forKey: "inputIntensity")
        return filter.outputImage ?? image
    }
    
    private func applyBlackAndWhite(to image: CIImage) -> CIImage {
        guard let filter = CIFilter(name: "CIPhotoEffectNoir") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage ?? image
    }
    
    private func applyColorControls(to image: CIImage, brightness: Double, contrast: Double, saturation: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value: brightness), forKey: "inputBrightness")
        filter.setValue(NSNumber(value: contrast), forKey: "inputContrast")
        filter.setValue(NSNumber(value: saturation), forKey: "inputSaturation")
        return filter.outputImage ?? image
    }
    
    private func applyBlur(to image: CIImage, radius: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value: radius), forKey: "inputRadius")
        return filter.outputImage ?? image
    }
    
    private func applySharpen(to image: CIImage, intensity: Double) -> CIImage {
        guard let filter = CIFilter(name: "CISharpenLuminance") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value: intensity), forKey: "inputSharpness")
        return filter.outputImage ?? image
    }
    
    private func applyVignette(to image: CIImage, intensity: Double, radius: Double) -> CIImage {
        guard let filter = CIFilter(name: "CIVignette") else { return image }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value: intensity), forKey: "inputIntensity")
        filter.setValue(NSNumber(value: radius), forKey: "inputRadius")
        return filter.outputImage ?? image
    }
}
#endif
