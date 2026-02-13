import Foundation
import AVFoundation
import CoreImage
import Vision
import CoreGraphics

// MARK: - 2. 遮罩和追踪系统

// MARK: - 遮罩类型

enum MaskType: String, Codable, CaseIterable {
    case rectangle = "矩形"
    case ellipse = "椭圆"
    case polygon = "多边形"
    case bezier = "贝塞尔曲线"
    case freehand = "自由绘制"
    case text = "文字形状"
    case feathered = "羽化遮罩"
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

// MARK: - 遮罩模型

struct VideoMask: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: MaskType
    var points: [MaskPoint]
    var isInverted: Bool
    var featherRadius: CGFloat
    var opacity: CGFloat
    var expansion: CGFloat

    // 时间范围
    var startTime: CMTime
    var endTime: CMTime

    // 关键帧（用于遮罩动画）
    var keyframes: [MaskKeyframe]

    // 追踪设置
    var trackingEnabled: Bool
    var trackingData: [TrackingPoint]?

    init(
        id: UUID = UUID(),
        name: String = "遮罩",
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

    // 创建矩形遮罩
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

    // 创建椭圆遮罩
    static func ellipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) -> VideoMask {
        var mask = VideoMask(type: .ellipse)
        // 使用贝塞尔曲线近似椭圆
        let kappa: CGFloat = 0.5522848  // 4/3 * (sqrt(2) - 1)

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

// MARK: - 追踪数据

struct TrackingPoint: Codable {
    var time: CMTime
    var position: CGPoint
    var scale: CGFloat
    var rotation: CGFloat
    var confidence: Float
}

// MARK: - 遮罩管理器

class MaskManager: ObservableObject {
    static let shared = MaskManager()

    @Published var masks: [VideoMask] = []
    @Published var selectedMaskId: UUID?

    private init() {}

    // 添加遮罩
    func addMask(_ mask: VideoMask) {
        masks.append(mask)
        selectedMaskId = mask.id
    }

    // 删除遮罩
    func removeMask(_ mask: VideoMask) {
        masks.removeAll { $0.id == mask.id }
    }

    // 更新遮罩
    func updateMask(_ mask: VideoMask) {
        if let index = masks.firstIndex(where: { $0.id == mask.id }) {
            masks[index] = mask
        }
    }

    // 复制遮罩
    func duplicateMask(_ mask: VideoMask) {
        var newMask = mask
        newMask.name = "\(mask.name) 副本"
        // 偏移一点位置
        newMask.points = mask.points.map {
            MaskPoint(x: $0.x + 0.05, y: $0.y + 0.05, controlPoint1: $0.controlPoint1, controlPoint2: $0.controlPoint2)
        }
        masks.append(newMask)
    }

    // 生成遮罩路径
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
                // 使用贝塞尔曲线绘制椭圆
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
            // 特殊处理
            break
        }

        return path
    }

    // 应用遮罩到图像
    func applyMask(_ mask: VideoMask, to image: CIImage) -> CIImage {
        let size = image.extent.size
        let path = generatePath(for: mask, in: size)

        // 创建遮罩图像
        let maskImage = createMaskImage(path: path, size: size, feather: mask.featherRadius, inverted: mask.isInverted)

        // 应用遮罩
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
        // 创建位图上下文
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

        // 填充背景
        context.setFillColor(inverted ? CGColor(gray: 1, alpha: 1) : CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))

        // 绘制遮罩
        context.setFillColor(inverted ? CGColor(gray: 0, alpha: 1) : CGColor(gray: 1, alpha: 1))
        context.addPath(path)
        context.fillPath()

        guard let cgImage = context.makeImage() else {
            return CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: size))
        }

        var maskImage = CIImage(cgImage: cgImage)

        // 应用羽化
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

// MARK: - 运动追踪

class MotionTracker: ObservableObject {
    static let shared = MotionTracker()

    @Published var isTracking = false
    @Published var trackingProgress: Double = 0
    @Published var trackingResults: [UUID: [TrackingPoint]] = [:]

    private let sequenceHandler = VNSequenceRequestHandler()

    private init() {}

    // 追踪点
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

        // 创建初始观察区域
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

    // 追踪矩形区域
    func trackRectangle(
        in asset: AVAsset,
        initialRect: CGRect,
        startTime: CMTime,
        endTime: CMTime
    ) async throws -> [TrackingPoint] {
        // 类似点追踪，但返回矩形的变换信息
        return try await trackPoint(in: asset, startPoint: CGPoint(x: initialRect.midX, y: initialRect.midY), startTime: startTime, endTime: endTime)
    }

    enum TrackingError: Error {
        case noVideoTrack
        case trackingFailed
    }
}

// MARK: - 物体追踪

class ObjectTracker: ObservableObject {
    static let shared = ObjectTracker()

    @Published var detectedObjects: [DetectedObject] = []
    @Published var isDetecting = false

    private init() {}

    struct DetectedObject: Identifiable {
        let id = UUID()
        var label: String
        var confidence: Float
        var boundingBox: CGRect
        var trackingId: UUID?
    }

    // 检测物体
    func detectObjects(in image: CGImage) async throws -> [DetectedObject] {
        isDetecting = true
        defer { isDetecting = false }

        var results: [DetectedObject] = []

        let request = VNRecognizeAnimalsRequest { request, error in
            guard let observations = request.results as? [VNRecognizedObjectObservation] else { return }

            for observation in observations {
                if let label = observation.labels.first {
                    let obj = DetectedObject(
                        label: label.identifier,
                        confidence: label.confidence,
                        boundingBox: observation.boundingBox
                    )
                    results.append(obj)
                }
            }
        }

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        detectedObjects = results
        return results
    }

    // 追踪检测到的物体
    func trackObject(_ object: DetectedObject, in asset: AVAsset, startTime: CMTime, endTime: CMTime) async throws -> [TrackingPoint] {
        let centerPoint = CGPoint(x: object.boundingBox.midX, y: object.boundingBox.midY)
        return try await MotionTracker.shared.trackPoint(
            in: asset,
            startPoint: centerPoint,
            startTime: startTime,
            endTime: endTime
        )
    }
}

// MARK: - 人脸追踪

class FaceTracker: ObservableObject {
    static let shared = FaceTracker()

    @Published var detectedFaces: [DetectedFace] = []
    @Published var isTracking = false

    private init() {}

    struct DetectedFace: Identifiable {
        let id = UUID()
        var boundingBox: CGRect
        var landmarks: VNFaceLandmarks2D?
        var roll: CGFloat?
        var yaw: CGFloat?
        var quality: Float?
    }

    // 检测人脸
    func detectFaces(in image: CGImage) async throws -> [DetectedFace] {
        var results: [DetectedFace] = []

        let request = VNDetectFaceLandmarksRequest { request, error in
            guard let observations = request.results as? [VNFaceObservation] else { return }

            for observation in observations {
                let face = DetectedFace(
                    boundingBox: observation.boundingBox,
                    landmarks: observation.landmarks,
                    roll: observation.roll.map { CGFloat($0.doubleValue) },
                    yaw: observation.yaw.map { CGFloat($0.doubleValue) },
                    quality: observation.faceCaptureQuality
                )
                results.append(face)
            }
        }

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        detectedFaces = results
        return results
    }

    // 追踪人脸
    func trackFaces(in asset: AVAsset, startTime: CMTime, endTime: CMTime) async throws -> [UUID: [TrackingPoint]] {
        isTracking = true
        defer { isTracking = false }

        var allResults: [UUID: [TrackingPoint]] = [:]

        guard let track = asset.tracks(withMediaType: .video).first else {
            throw TrackingError.noVideoTrack
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let duration = CMTimeSubtract(endTime, startTime)
        let frameRate = track.nominalFrameRate
        let totalFrames = Int(CMTimeGetSeconds(duration) * Double(frameRate))

        // 第一帧检测所有人脸
        let firstFrameTime = startTime
        guard let firstImage = try? generator.copyCGImage(at: firstFrameTime, actualTime: nil) else {
            throw TrackingError.noVideoTrack
        }

        let initialFaces = try await detectFaces(in: firstImage)

        // 为每个人脸创建追踪
        for face in initialFaces {
            let centerPoint = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
            let trackingPoints = try await MotionTracker.shared.trackPoint(
                in: asset,
                startPoint: centerPoint,
                startTime: startTime,
                endTime: endTime,
                trackerId: face.id
            )
            allResults[face.id] = trackingPoints
        }

        return allResults
    }

    enum TrackingError: Error {
        case noVideoTrack
    }
}

// MARK: - 手势识别

class GestureRecognizer: ObservableObject {
    static let shared = GestureRecognizer()

    @Published var detectedGestures: [DetectedGesture] = []

    private init() {}

    struct DetectedGesture: Identifiable {
        let id = UUID()
        var type: GestureType
        var confidence: Float
        var handedness: Handedness
        var landmarks: [CGPoint]
    }

    enum GestureType: String, CaseIterable {
        case thumbsUp = "竖起大拇指"
        case thumbsDown = "向下大拇指"
        case victory = "胜利手势"
        case ok = "OK手势"
        case fist = "拳头"
        case openPalm = "张开手掌"
        case pointingUp = "指向上方"
        case heart = "比心"
        case unknown = "未知"
    }

    enum Handedness {
        case left, right, unknown
    }

    // 检测手势
    func detectGestures(in image: CGImage) async throws -> [DetectedGesture] {
        var results: [DetectedGesture] = []

        let request = VNDetectHumanHandPoseRequest { request, error in
            guard let observations = request.results as? [VNHumanHandPoseObservation] else { return }

            for observation in observations {
                // 获取手部关键点
                var landmarks: [CGPoint] = []

                if let thumbTip = try? observation.recognizedPoint(.thumbTip),
                   thumbTip.confidence > 0.5 {
                    landmarks.append(CGPoint(x: thumbTip.location.x, y: thumbTip.location.y))
                }

                if let indexTip = try? observation.recognizedPoint(.indexTip),
                   indexTip.confidence > 0.5 {
                    landmarks.append(CGPoint(x: indexTip.location.x, y: indexTip.location.y))
                }

                // 简化手势识别
                let gestureType = self.classifyGesture(observation: observation)

                let gesture = DetectedGesture(
                    type: gestureType,
                    confidence: 0.8,
                    handedness: observation.chirality == .left ? .left : .right,
                    landmarks: landmarks
                )
                results.append(gesture)
            }
        }

        request.maximumHandCount = 2

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        detectedGestures = results
        return results
    }

    private func classifyGesture(observation: VNHumanHandPoseObservation) -> GestureType {
        // 简化的手势分类逻辑
        // 实际应该使用更复杂的算法或ML模型

        guard let thumbTip = try? observation.recognizedPoint(.thumbTip),
              let indexTip = try? observation.recognizedPoint(.indexTip),
              let middleTip = try? observation.recognizedPoint(.middleTip),
              let ringTip = try? observation.recognizedPoint(.ringTip),
              let littleTip = try? observation.recognizedPoint(.littleTip),
              let wrist = try? observation.recognizedPoint(.wrist) else {
            return .unknown
        }

        // 检测竖起大拇指
        if thumbTip.location.y > wrist.location.y + 0.2 &&
           indexTip.location.y < thumbTip.location.y - 0.1 {
            return .thumbsUp
        }

        // 检测胜利手势
        if indexTip.location.y > wrist.location.y + 0.15 &&
           middleTip.location.y > wrist.location.y + 0.15 &&
           ringTip.location.y < indexTip.location.y - 0.1 {
            return .victory
        }

        // 检测OK手势
        let thumbIndexDistance = hypot(thumbTip.location.x - indexTip.location.x,
                                       thumbTip.location.y - indexTip.location.y)
        if thumbIndexDistance < 0.1 {
            return .ok
        }

        return .unknown
    }

    // 在视频中追踪手势
    func trackGestures(in asset: AVAsset, trigger: GestureType) async throws -> [(time: CMTime, gesture: DetectedGesture)] {
        var results: [(time: CMTime, gesture: DetectedGesture)] = []

        guard let track = asset.tracks(withMediaType: .video).first else { return results }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let duration = asset.duration
        let frameRate = track.nominalFrameRate
        let sampleInterval = 5  // 每5帧采样一次
        let totalSamples = Int(CMTimeGetSeconds(duration) * Double(frameRate)) / sampleInterval

        for sampleIndex in 0..<totalSamples {
            let frameIndex = sampleIndex * sampleInterval
            let time = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(frameRate))

            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                continue
            }

            let gestures = try await detectGestures(in: cgImage)

            for gesture in gestures where gesture.type == trigger {
                results.append((time: time, gesture: gesture))
            }
        }

        return results
    }
}

// MARK: - 遮罩追踪器

class MaskTracker: ObservableObject {
    static let shared = MaskTracker()

    @Published var isTracking = false
    @Published var trackingProgress: Double = 0

    private init() {}

    // 追踪遮罩
    func trackMask(_ mask: VideoMask, in asset: AVAsset, from startTime: CMTime, to endTime: CMTime) async throws -> [MaskKeyframe] {
        isTracking = true
        defer { isTracking = false }

        var keyframes: [MaskKeyframe] = []

        // 获取遮罩中心点
        let centerX = mask.points.reduce(0) { $0 + $1.x } / CGFloat(mask.points.count)
        let centerY = mask.points.reduce(0) { $0 + $1.y } / CGFloat(mask.points.count)
        let centerPoint = CGPoint(x: centerX, y: centerY)

        // 追踪中心点
        let trackingPoints = try await MotionTracker.shared.trackPoint(
            in: asset,
            startPoint: centerPoint,
            startTime: startTime,
            endTime: endTime
        )

        // 根据追踪结果生成关键帧
        for trackingPoint in trackingPoints {
            let offsetX = trackingPoint.position.x - centerX
            let offsetY = trackingPoint.position.y - centerY

            // 偏移所有点
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
