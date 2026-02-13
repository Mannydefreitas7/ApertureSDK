import Foundation
import AVFoundation
import CoreImage
import Vision
import CoreGraphics

// MARK: - Masking and Tracking System

// MARK: - Mask Types

enum MaskType: String, Codable, CaseIterable {
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case polygon = "Polygon"
    case bezier = "Bezier"
    case freehand = "Freehand"
    case text = "Text"
    case feathered = "Feathered"
}

struct MaskPoint: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var controlPoint1: CGPoint?
    var controlPoint2: CGPoint?

    var point: CGPoint {
        CGPoint(x: x, y: y)
    }

    init(x: CGFloat, y: CGFloat, controlPoint1: CGPoint? = nil, controlPoint2: CGPoint? = nil) {
        self.x = x
        self.y = y
        self.controlPoint1 = controlPoint1
        self.controlPoint2 = controlPoint2
    }

    init(point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
}

// MARK: - Mask Model

struct VideoMask: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: MaskType
    var points: [MaskPoint]
    var isInverted: Bool
    var featherRadius: CGFloat
    var opacity: CGFloat
    var expansion: CGFloat

    // Time range
    var startTime: CMTime
    var endTime: CMTime

    // Keyframes (for mask animation)
    var keyframes: [MaskKeyframe]

    // Tracking settings
    var trackingEnabled: Bool
    var trackingData: [TrackingPoint]?

    init(
        id: UUID = UUID(),
        name: String = "Mask",
        type: MaskType = .rectangle,
        points: [MaskPoint] = [],
        isInverted: Bool = false,
        featherRadius: CGFloat = 0,
        opacity: CGFloat = 1.0,
        expansion: CGFloat = 0,
        startTime: CMTime = .zero,
        endTime: CMTime = .positiveInfinity,
        keyframes: [MaskKeyframe] = [],
        trackingEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.points = points
        self.isInverted = isInverted
        self.featherRadius = featherRadius
        self.opacity = opacity
        self.expansion = expansion
        self.startTime = startTime
        self.endTime = endTime
        self.keyframes = keyframes
        self.trackingEnabled = trackingEnabled
    }

    // Create rectangle mask
    static func rectangle(rect: CGRect) -> VideoMask {
        VideoMask(
            type: .rectangle,
            points: [
                MaskPoint(x: rect.minX, y: rect.minY),
                MaskPoint(x: rect.maxX, y: rect.minY),
                MaskPoint(x: rect.maxX, y: rect.maxY),
                MaskPoint(x: rect.minX, y: rect.maxY)
            ]
        )
    }

    // Create ellipse mask
    static func ellipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) -> VideoMask {
        var mask = VideoMask(type: .ellipse)
        let kappa: CGFloat = 0.5522848

        mask.points = [
            MaskPoint(x: center.x, y: center.y - radiusY,
                     controlPoint1: CGPoint(x: center.x - radiusX * kappa, y: center.y - radiusY),
                     controlPoint2: CGPoint(x: center.x + radiusX * kappa, y: center.y - radiusY)),
            MaskPoint(x: center.x + radiusX, y: center.y,
                     controlPoint1: CGPoint(x: center.x + radiusX, y: center.y - radiusY * kappa),
                     controlPoint2: CGPoint(x: center.x + radiusX, y: center.y + radiusY * kappa)),
            MaskPoint(x: center.x, y: center.y + radiusY,
                     controlPoint1: CGPoint(x: center.x + radiusX * kappa, y: center.y + radiusY),
                     controlPoint2: CGPoint(x: center.x - radiusX * kappa, y: center.y + radiusY)),
            MaskPoint(x: center.x - radiusX, y: center.y,
                     controlPoint1: CGPoint(x: center.x - radiusX, y: center.y + radiusY * kappa),
                     controlPoint2: CGPoint(x: center.x - radiusX, y: center.y - radiusY * kappa))
        ]
        return mask
    }
}

struct MaskKeyframe: Codable {
    var time: CMTime
    var points: [MaskPoint]
    var featherRadius: CGFloat
    var opacity: CGFloat
}

// MARK: - Tracking Data

struct TrackingPoint: Codable {
    var time: CMTime
    var position: CGPoint
    var scale: CGFloat
    var rotation: CGFloat
    var confidence: Float
}

// MARK: - Mask Manager

class MaskManager: ObservableObject {
    static let shared = MaskManager()

    @Published var masks: [VideoMask] = []
    @Published var selectedMaskId: UUID?

    private init() {}

    func addMask(_ mask: VideoMask) {
        masks.append(mask)
        selectedMaskId = mask.id
    }

    func removeMask(_ mask: VideoMask) {
        masks.removeAll { $0.id == mask.id }
    }

    func updateMask(_ mask: VideoMask) {
        if let index = masks.firstIndex(where: { $0.id == mask.id }) {
            masks[index] = mask
        }
    }

    func duplicateMask(_ mask: VideoMask) {
        var newMask = mask
        newMask.name = "\(mask.name) Copy"
        newMask.points = mask.points.map {
            MaskPoint(x: $0.x + 0.05, y: $0.y + 0.05, controlPoint1: $0.controlPoint1, controlPoint2: $0.controlPoint2)
        }
        masks.append(newMask)
    }

    func generatePath(for mask: VideoMask, in size: CGSize) -> CGPath {
        let path = CGMutablePath()

        switch mask.type {
        case .rectangle:
            if mask.points.count >= 4 {
                let rect = CGRect(
                    x: mask.points[0].x * size.width,
                    y: mask.points[0].y * size.height,
                    width: (mask.points[1].x - mask.points[0].x) * size.width,
                    height: (mask.points[3].y - mask.points[0].y) * size.height
                )
                path.addRect(rect)
            }

        case .ellipse:
            if mask.points.count >= 4 {
                let firstPoint = CGPoint(
                    x: mask.points[0].x * size.width,
                    y: mask.points[0].y * size.height
                )
                path.move(to: firstPoint)

                for i in 0..<mask.points.count {
                    let nextIndex = (i + 1) % mask.points.count
                    let current = mask.points[i]
                    let next = mask.points[nextIndex]

                    if let cp1 = current.controlPoint2, let cp2 = next.controlPoint1 {
                        path.addCurve(
                            to: CGPoint(x: next.x * size.width, y: next.y * size.height),
                            control1: CGPoint(x: cp1.x * size.width, y: cp1.y * size.height),
                            control2: CGPoint(x: cp2.x * size.width, y: cp2.y * size.height)
                        )
                    }
                }
                path.closeSubpath()
            }

        case .polygon, .freehand:
            if let first = mask.points.first {
                path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                for point in mask.points.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                }
                path.closeSubpath()
            }

        case .bezier:
            if let first = mask.points.first {
                path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                for i in 1..<mask.points.count {
                    let point = mask.points[i]
                    if let cp1 = mask.points[i-1].controlPoint2, let cp2 = point.controlPoint1 {
                        path.addCurve(
                            to: CGPoint(x: point.x * size.width, y: point.y * size.height),
                            control1: CGPoint(x: cp1.x * size.width, y: cp1.y * size.height),
                            control2: CGPoint(x: cp2.x * size.width, y: cp2.y * size.height)
                        )
                    } else {
                        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                    }
                }
                path.closeSubpath()
            }

        case .text, .feathered:
            break
        }

        return path
    }

    func applyMask(_ mask: VideoMask, to image: CIImage) -> CIImage {
        let size = image.extent.size
        let path = generatePath(for: mask, in: size)

        let maskImage = createMaskImage(path: path, size: size, feather: mask.featherRadius, inverted: mask.isInverted)

        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            return image
        }

        let transparent = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
            .cropped(to: image.extent)

        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(transparent, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)

        return blendFilter.outputImage ?? image
    }

    private func createMaskImage(path: CGPath, size: CGSize, feather: CGFloat, inverted: Bool) -> CIImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: size))
        }

        context.setFillColor(inverted ? CGColor(gray: 1, alpha: 1) : CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))

        context.setFillColor(inverted ? CGColor(gray: 0, alpha: 1) : CGColor(gray: 1, alpha: 1))
        context.addPath(path)
        context.fillPath()

        guard let cgImage = context.makeImage() else {
            return CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: size))
        }

        var maskImage = CIImage(cgImage: cgImage)

        if feather > 0 {
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(maskImage, forKey: kCIInputImageKey)
                blurFilter.setValue(feather, forKey: kCIInputRadiusKey)
                if let output = blurFilter.outputImage {
                    maskImage = output.cropped(to: CGRect(origin: .zero, size: size))
                }
            }
        }

        return maskImage
    }
}

// MARK: - Motion Tracking

class MotionTracker: ObservableObject {
    static let shared = MotionTracker()

    @Published var isTracking = false
    @Published var trackingProgress: Double = 0
    @Published var trackingResults: [UUID: [TrackingPoint]] = [:]

    private let sequenceHandler = VNSequenceRequestHandler()

    private init() {}

    func trackPoint(
        in asset: AVAsset,
        startPoint: CGPoint,
        startTime: CMTime,
        endTime: CMTime,
        trackerId: UUID = UUID()
    ) async throws -> [TrackingPoint] {
        isTracking = true
        defer { isTracking = false }

        var results: [TrackingPoint] = []

        guard let track = asset.tracks(withMediaType: .video).first else {
            throw TrackingError.noVideoTrack
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.01, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.01, preferredTimescale: 600)

        let duration = CMTimeSubtract(endTime, startTime)
        let frameRate = track.nominalFrameRate
        let totalFrames = Int(CMTimeGetSeconds(duration) * Double(frameRate))

        var previousObservation: VNDetectedObjectObservation?

        let initialRect = CGRect(
            x: startPoint.x - 0.05,
            y: startPoint.y - 0.05,
            width: 0.1,
            height: 0.1
        )

        for frameIndex in 0..<totalFrames {
            let time = CMTimeAdd(startTime, CMTime(seconds: Double(frameIndex) / Double(frameRate), preferredTimescale: 600))

            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                continue
            }

            let trackingRequest: VNTrackObjectRequest

            if let previous = previousObservation {
                trackingRequest = VNTrackObjectRequest(detectedObjectObservation: previous)
            } else {
                let initialObservation = VNDetectedObjectObservation(boundingBox: initialRect)
                trackingRequest = VNTrackObjectRequest(detectedObjectObservation: initialObservation)
            }

            trackingRequest.trackingLevel = .accurate

            try sequenceHandler.perform([trackingRequest], on: cgImage)

            if let result = trackingRequest.results?.first as? VNDetectedObjectObservation {
                let boundingBox = result.boundingBox
                let centerPoint = CGPoint(
                    x: boundingBox.midX,
                    y: boundingBox.midY
                )

                let trackingPoint = TrackingPoint(
                    time: time,
                    position: centerPoint,
                    scale: 1.0,
                    rotation: 0,
                    confidence: result.confidence
                )
                results.append(trackingPoint)

                previousObservation = result
            }

            trackingProgress = Double(frameIndex) / Double(totalFrames)
        }

        trackingResults[trackerId] = results
        return results
    }

    func trackRectangle(
        in asset: AVAsset,
        initialRect: CGRect,
        startTime: CMTime,
        endTime: CMTime
    ) async throws -> [TrackingPoint] {
        return try await trackPoint(in: asset, startPoint: CGPoint(x: initialRect.midX, y: initialRect.midY), startTime: startTime, endTime: endTime)
    }

    enum TrackingError: Error {
        case noVideoTrack
        case trackingFailed
    }
}

// MARK: - Mask Tracker

class MaskTracker: ObservableObject {
    static let shared = MaskTracker()

    @Published var isTracking = false
    @Published var trackingProgress: Double = 0

    private init() {}

    func trackMask(_ mask: VideoMask, in asset: AVAsset, from startTime: CMTime, to endTime: CMTime) async throws -> [MaskKeyframe] {
        isTracking = true
        defer { isTracking = false }

        var keyframes: [MaskKeyframe] = []

        let centerX = mask.points.reduce(0) { $0 + $1.x } / CGFloat(mask.points.count)
        let centerY = mask.points.reduce(0) { $0 + $1.y } / CGFloat(mask.points.count)
        let centerPoint = CGPoint(x: centerX, y: centerY)

        let trackingPoints = try await MotionTracker.shared.trackPoint(
            in: asset,
            startPoint: centerPoint,
            startTime: startTime,
            endTime: endTime
        )

        for trackingPoint in trackingPoints {
            let offsetX = trackingPoint.position.x - centerX
            let offsetY = trackingPoint.position.y - centerY

            let newPoints = mask.points.map { point in
                MaskPoint(
                    x: point.x + offsetX,
                    y: point.y + offsetY,
                    controlPoint1: point.controlPoint1.map {
                        CGPoint(x: $0.x + offsetX, y: $0.y + offsetY)
                    },
                    controlPoint2: point.controlPoint2.map {
                        CGPoint(x: $0.x + offsetX, y: $0.y + offsetY)
                    }
                )
            }

            let keyframe = MaskKeyframe(
                time: trackingPoint.time,
                points: newPoints,
                featherRadius: mask.featherRadius,
                opacity: mask.opacity
            )
            keyframes.append(keyframe)

            trackingProgress = Double(keyframes.count) / Double(trackingPoints.count)
        }

        return keyframes
    }
}
