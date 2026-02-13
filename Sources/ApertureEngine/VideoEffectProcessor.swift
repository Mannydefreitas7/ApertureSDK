//
//  VideoEffectProcessor.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import AVFoundation

// MARK: - Video Effect Processor

/// Video effect processor
actor VideoEffectProcessor {
    private let context: CIContext
    static let shared = VideoEffectProcessor()

    private init() {
        if let device = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: device)
        } else {
            context = CIContext()
        }
    }

    /// Apply chroma key (green screen)
    func applyChromaKey(_ chromaKey: ChromaKey, to image: CIImage) -> CIImage {
        guard chromaKey.isEnabled,
              let filter = chromaKey.makeCIFilter() else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage ?? image
    }

    /// Apply blur effect
    func applyBlur(_ blur: BlurEffect, to image: CIImage) -> CIImage {
        guard let filter = blur.type.makeCIFilter(radius: blur.radius) else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)

        guard let blurredImage = filter.outputImage else {
            return image
        }

        // If regional blur, need to composite
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

    /// Create rectangle mask
    private func rectangleMask(_ rect: CGRect, size: CGSize) -> CIImage {
        let color = CIColor(red: 1, green: 1, blue: 1)
        let colorImage = CIImage(color: color).cropped(to: CGRect(origin: .zero, size: size))

        // Create white rectangle
        let whiteRect = CIImage(color: color).cropped(to: rect)

        // Place white rectangle on black background
        let blackImage = CIImage(color: CIColor.black).cropped(to: CGRect(origin: .zero, size: size))

        let compositeFilter = CIFilter.sourceOverCompositing()
        compositeFilter.inputImage = whiteRect
        compositeFilter.backgroundImage = blackImage

        return compositeFilter.outputImage ?? blackImage
    }

    /// Create circle mask
    private func circleMask(center: CGPoint, radius: CGFloat, size: CGSize) -> CIImage {
        let filter = CIFilter.radialGradient()
        filter.center = center
        filter.radius0 = Float(radius * 0.8)
        filter.radius1 = Float(radius)
        filter.color0 = CIColor.white
        filter.color1 = CIColor.black

        return filter.outputImage?.cropped(to: CGRect(origin: .zero, size: size)) ?? CIImage()
    }

    /// Composite blur
    private func compositeBlur(original: CIImage, blurred: CIImage, mask: CIImage) -> CIImage {
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = blurred
        blendFilter.backgroundImage = original
        blendFilter.maskImage = mask

        return blendFilter.outputImage ?? original
    }

    /// Apply mosaic
    func applyMosaic(_ mosaic: MosaicEffect, to image: CIImage) -> CIImage {
        guard let filter = mosaic.makeCIFilter() else {
            return image
        }

        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage ?? image
    }
}
