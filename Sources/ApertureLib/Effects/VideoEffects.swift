import Foundation
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Picture in Picture

/// Picture in picture configuration
struct PictureInPicture: Identifiable {
    let id: UUID
    var overlayClipId: UUID  // Overlay clip

    /// Position (normalized 0-1)
    var position: CGPoint = CGPoint(x: 0.8, y: 0.2)

    /// Size (relative to frame)
    var scale: CGFloat = 0.3

    /// Border
    var borderWidth: CGFloat = 2
    var borderColor: Color = Color(.white)

    /// Corner radius
    var cornerRadius: CGFloat = 8

    /// Shadow
    var shadowEnabled: Bool = true
    var shadowColor: Color = Color(.black.withAlphaComponent(0.5))
    var shadowOffset: CGSize = CGSize(width: 2, height: 2)
    var shadowRadius: CGFloat = 8

    /// Time range
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

/// Picture in picture position presets
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

// MARK: - Green Screen/Chroma Key

/// Chroma key (green screen) effect
struct ChromaKey: Identifiable, Equatable {
    let id: UUID

    /// Color to remove
    var keyColor: Color = Color(.green)

    /// Color tolerance
    var tolerance: Float = 0.4

    /// Edge softness
    var softness: Float = 0.1

    /// Spill suppression
    var spillSuppression: Float = 0.5

    /// Whether enabled
    var isEnabled: Bool = true

    init(id: UUID = UUID()) {
        self.id = id
    }

    /// Create CIFilter
    func makeCIFilter() -> CIFilter? {
        // Use CIColorCube to implement chroma key
        let filter = CIFilter(name: "CIColorCube")

        // Create color lookup table
        let size = 64
        var cubeData = [Float](repeating: 0, count: size * size * size * 4)

        let ciKeyColor: CIColor
#if canImport(UIKit)
        ciKeyColor = CIColor(color: UIColor(keyColor))
#elseif canImport(AppKit)
        ciKeyColor = CIColor(color: NSColor(keyColor))
#else
        ciKeyColor = CIColor(red: 0, green: 1, blue: 0)
#endif

        let keyR = Float(ciKeyColor.red)
        let keyG = Float(ciKeyColor.green)
        let keyB = Float(ciKeyColor.blue)

        for b in 0..<size {
            for g in 0..<size {
                for r in 0..<size {
                    let index = (b * size * size + g * size + r) * 4

                    let rf = Float(r) / Float(size - 1)
                    let gf = Float(g) / Float(size - 1)
                    let bf = Float(b) / Float(size - 1)

                    // Calculate distance to key color
                    let distance = sqrt(
                        pow(rf - keyR, 2) +
                        pow(gf - keyG, 2) +
                        pow(bf - keyB, 2)
                    )

                    // Calculate alpha
                    var alpha: Float
                    if distance < tolerance {
                        alpha = 0
                    } else if distance < tolerance + softness {
                        alpha = (distance - tolerance) / softness
                    } else {
                        alpha = 1
                    }

                    // Premultiplied alpha
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

// MARK: - Blur Effects

/// Blur effect
struct BlurEffect: Identifiable, Equatable {
    let id: UUID
    var type: BlurType = .gaussian
    var radius: CGFloat = 10
    var region: BlurRegion = .fullFrame
    var isAnimated: Bool = false

    init(id: UUID = UUID()) {
        self.id = id
    }

    /// Blur type
    enum BlurType: String, CaseIterable {
        case gaussian = "Gaussian Blur"
        case motion = "Motion Blur"
        case zoom = "Zoom Blur"
        case box = "Box Blur"
        case disc = "Disc Blur"

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

    /// Blur region
    enum BlurRegion: Equatable {
        case fullFrame           // Full frame
        case rectangle(CGRect)   // Rectangle area
        case circle(center: CGPoint, radius: CGFloat)  // Circle area
        case faceTracking        // Face tracking
        case custom(mask: String) // Custom mask
    }
}

/// Mosaic effect
struct MosaicEffect: Identifiable, Equatable {
    let id: UUID
    var blockSize: CGFloat = 20
    var region: BlurEffect.BlurRegion = .fullFrame
    var shape: MosaicShape = .square

    init(id: UUID = UUID()) {
        self.id = id
    }

    enum MosaicShape: String, CaseIterable {
        case square = "Square"
        case hexagon = "Hexagon"
        case circle = "Circle"
    }

    func makeCIFilter() -> CIFilter? {
        let filter = CIFilter.pixellate()
        filter.scale = Float(blockSize)
        return filter
    }
}

// MARK: - Speed Curves

/// Speed curve
struct SpeedCurve: Identifiable, Equatable {
    let id: UUID
    var keyframes: [SpeedKeyframe] = []

    init(id: UUID = UUID()) {
        self.id = id
    }

    /// Speed keyframe
    struct SpeedKeyframe: Identifiable, Equatable {
        let id: UUID
        var time: CGFloat  // Normalized time 0-1
        var speed: CGFloat // Speed multiplier

        init(id: UUID = UUID(), time: CGFloat, speed: CGFloat) {
            self.id = id
            self.time = time
            self.speed = speed
        }
    }

    /// Preset speed curves
    enum Preset: String, CaseIterable {
        case normal = "Normal"
        case slowMotion = "Slow Motion"
        case fastMotion = "Fast Motion"
        case rampUp = "Ramp Up"
        case rampDown = "Ramp Down"
        case pulse = "Pulse"
        case reverse = "Reverse"

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

    /// Get speed at specified progress
    func speed(at progress: CGFloat) -> CGFloat {
        guard !keyframes.isEmpty else { return 1 }
        guard keyframes.count > 1 else { return keyframes[0].speed }

        let sorted = keyframes.sorted { $0.time < $1.time }

        // Find surrounding keyframes
        var prev = sorted[0]
        var next = sorted[sorted.count - 1]

        for i in 0..<sorted.count - 1 {
            if sorted[i].time <= progress && sorted[i + 1].time >= progress {
                prev = sorted[i]
                next = sorted[i + 1]
                break
            }
        }

        // Linear interpolation
        if next.time == prev.time { return prev.speed }

        let t = (progress - prev.time) / (next.time - prev.time)
        return prev.speed + (next.speed - prev.speed) * t
    }
}

// MARK: - Split Screen Effects

/// Split screen effect
struct SplitScreen: Identifiable {
    let id: UUID
    var layout: SplitLayout
    var clips: [UUID]  // Clip IDs participating in split screen
    var borderWidth: CGFloat = 2
    var borderColor: Color = Color(.white)

    init(id: UUID = UUID(), layout: SplitLayout, clips: [UUID]) {
        self.id = id
        self.layout = layout
        self.clips = clips
    }

    /// Split screen layout
    enum SplitLayout: String, CaseIterable {
        case horizontal2 = "Left-Right Split"
        case vertical2 = "Top-Bottom Split"
        case grid4 = "Four Grid"
        case grid9 = "Nine Grid"
        case pip = "Picture in Picture"
        case diagonal = "Diagonal Split"

        var clipCount: Int {
            switch self {
            case .horizontal2, .vertical2, .pip, .diagonal: return 2
            case .grid4: return 4
            case .grid9: return 9
            }
        }

        /// Get region for each clip
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

// MARK: - LUT (Lookup Table)

/// LUT color grading
struct LUTFilter: Identifiable, Equatable {
    let id: UUID
    var name: String
    var intensity: Float = 1.0
    var lutData: Data?

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    /// Built-in LUT presets
    enum Preset: String, CaseIterable {
        case cinematic = "Cinematic"
        case vintage = "Vintage Film"
        case teal_orange = "Teal Orange"
        case bleach = "Bleach Bypass"
        case noir = "Film Noir"
        case vibrant = "Vibrant"
        case muted = "Muted"
        case warm_sunset = "Warm Sunset"
        case cool_morning = "Cool Morning"
        case cyberpunk = "Cyberpunk"

        var displayName: String { rawValue }
    }

    /// Load LUT from file
    static func load(from url: URL) throws -> LUTFilter {
        let data = try Data(contentsOf: url)
        var lut = LUTFilter(name: url.deletingPathExtension().lastPathComponent)
        lut.lutData = data
        return lut
    }

    /// Create CIFilter
    func makeCIFilter() -> CIFilter? {
        guard let data = lutData else { return nil }

        let filter = CIFilter(name: "CIColorCubeWithColorSpace")
        filter?.setValue(64, forKey: "inputCubeDimension")
        filter?.setValue(data, forKey: "inputCubeData")
        filter?.setValue(CGColorSpace(name: CGColorSpace.sRGB), forKey: "inputColorSpace")

        return filter
    }
}

// MARK: - Video Stabilization

/// Video stabilization configuration
struct VideoStabilization: Equatable {
    var isEnabled: Bool = true
    var strength: Float = 0.5  // 0-1
    var smoothness: Float = 0.5
    var cropRatio: Float = 0.1  // Crop ratio

    /// Stabilization mode
    enum Mode: String, CaseIterable {
        case standard = "Standard"
        case cinematic = "Cinematic"
        case auto = "Auto"
    }

    var mode: Mode = .standard
}

// MARK: - Lens Correction

/// Lens distortion correction
struct LensCorrection: Equatable {
    var isEnabled: Bool = false

    /// Barrel/Pincushion distortion (-1 to 1)
    var distortion: Float = 0

    /// Chromatic aberration correction
    var chromaticAberration: Float = 0

    /// Vignette correction
    var vignetteCorrection: Float = 0

    /// Preset lens configurations
    enum LensPreset: String, CaseIterable {
        case none = "None"
        case gopro_wide = "GoPro Wide"
        case iphone_wide = "iPhone Wide"
        case iphone_ultra = "iPhone Ultra Wide"
        case dji_mavic = "DJI Mavic"
        case custom = "Custom"
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

