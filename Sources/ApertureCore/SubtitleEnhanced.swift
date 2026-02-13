import Foundation
import AVFoundation
import CoreImage
import CoreGraphics
import CoreText

// MARK: - 6. Subtitle Enhancement Module

// MARK: - Karaoke Subtitles

struct KaraokeSubtitle: Identifiable, Codable {
    let id: UUID
    var lyrics: [KaraokeLine]
    var style: KaraokeStyle

    init(id: UUID = UUID(), lyrics: [KaraokeLine] = [], style: KaraokeStyle = KaraokeStyle()) {
        self.id = id
        self.lyrics = lyrics
        self.style = style
    }
}

struct KaraokeLine: Identifiable, Codable {
    let id: UUID
    var text: String
    var words: [KaraokeWord]
    var startTime: CMTime
    var endTime: CMTime

    init(id: UUID = UUID(), text: String, words: [KaraokeWord], startTime: CMTime, endTime: CMTime) {
        self.id = id
        self.text = text
        self.words = words
        self.startTime = startTime
        self.endTime = endTime
    }
}

struct KaraokeWord: Identifiable, Codable {
    let id: UUID
    var text: String
    var startTime: CMTime
    var endTime: CMTime

    init(id: UUID = UUID(), text: String, startTime: CMTime, endTime: CMTime) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}

struct KaraokeStyle: Codable {
    var font: String = "PingFang SC"
    var fontSize: CGFloat = 36
    var normalColor: CodableColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 1)
    var highlightColor: CodableColor = CodableColor(red: 1, green: 0.8, blue: 0, alpha: 1)
    var outlineColor: CodableColor = CodableColor(red: 0, green: 0, blue: 0, alpha: 1)
    var outlineWidth: CGFloat = 2
    var glowColor: CodableColor?
    var glowRadius: CGFloat = 0
    var position: CGPoint = CGPoint(x: 0.5, y: 0.9)
    var highlightStyle: KaraokeHighlightStyle = .fillLeft
}

enum KaraokeHighlightStyle: String, Codable, CaseIterable {
    case fillLeft = "Fill Left"
    case fillRight = "Fill Right"
    case grow = "Grow"
    case glow = "Glow"
    case colorChange = "Color Change"
}

class KaraokeRenderer: ObservableObject {
    static let shared = KaraokeRenderer()

    @Published var currentSubtitle: KaraokeSubtitle?

    private init() {}

    // Parse LRC lyrics file
    func parseLRC(_ content: String) -> [KaraokeLine] {
        var lines: [KaraokeLine] = []

        let pattern = "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.+)"
        let regex = try? NSRegularExpression(pattern: pattern)

        let nsContent = content as NSString
        let matches = regex?.matches(in: content, range: NSRange(location: 0, length: nsContent.length)) ?? []

        for match in matches {
            guard match.numberOfRanges >= 5 else { continue }

            let minutes = Int(nsContent.substring(with: match.range(at: 1))) ?? 0
            let seconds = Int(nsContent.substring(with: match.range(at: 2))) ?? 0
            let milliseconds = Int(nsContent.substring(with: match.range(at: 3))) ?? 0
            let text = nsContent.substring(with: match.range(at: 4))

            let totalSeconds = Double(minutes * 60 + seconds) + Double(milliseconds) / (milliseconds > 99 ? 1000 : 100)
            let startTime = CMTime(seconds: totalSeconds, preferredTimescale: 600)

            // Create words (simplified: split by space)
            let wordTexts = text.components(separatedBy: " ")
            var words: [KaraokeWord] = []
            let wordDuration = 0.5  // Simplified: 0.5 seconds per word

            for (index, wordText) in wordTexts.enumerated() {
                let wordStart = CMTimeAdd(startTime, CMTime(seconds: Double(index) * wordDuration, preferredTimescale: 600))
                let wordEnd = CMTimeAdd(wordStart, CMTime(seconds: wordDuration, preferredTimescale: 600))
                words.append(KaraokeWord(text: wordText, startTime: wordStart, endTime: wordEnd))
            }

            let line = KaraokeLine(
                text: text,
                words: words,
                startTime: startTime,
                endTime: CMTimeAdd(startTime, CMTime(seconds: Double(wordTexts.count) * wordDuration, preferredTimescale: 600))
            )
            lines.append(line)
        }

        return lines
    }

    // Render karaoke subtitle
    func render(
        subtitle: KaraokeSubtitle,
        at time: CMTime,
        size: CGSize
    ) -> CIImage? {
        // Find current line
        guard let currentLine = subtitle.lyrics.first(where: {
            CMTimeCompare(time, $0.startTime) >= 0 && CMTimeCompare(time, $0.endTime) <= 0
        }) else {
            return nil
        }

        // Calculate highlight progress
        let lineProgress = CMTimeGetSeconds(CMTimeSubtract(time, currentLine.startTime)) /
                          CMTimeGetSeconds(CMTimeSubtract(currentLine.endTime, currentLine.startTime))

        return renderLine(currentLine, style: subtitle.style, progress: lineProgress, size: size)
    }

    private func renderLine(_ line: KaraokeLine, style: KaraokeStyle, progress: Double, size: CGSize) -> CIImage? {
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext

            // Set font
            let font = UIFont(name: style.font, size: style.fontSize) ?? UIFont.systemFont(ofSize: style.fontSize)

            // Calculate text position
            let textSize = line.text.size(withAttributes: [.font: font])
            let x = (size.width - textSize.width) / 2
            let y = size.height * style.position.y - textSize.height / 2

            // Draw outline
            if style.outlineWidth > 0 {
                cgContext.setLineWidth(style.outlineWidth * 2)
                cgContext.setLineJoin(.round)
                cgContext.setTextDrawingMode(.stroke)

                let outlineAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor(
                        red: style.outlineColor.red,
                        green: style.outlineColor.green,
                        blue: style.outlineColor.blue,
                        alpha: style.outlineColor.alpha
                    )
                ]
                line.text.draw(at: CGPoint(x: x, y: y), withAttributes: outlineAttrs)
            }

            // Draw normal text
            cgContext.setTextDrawingMode(.fill)
            let normalAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(
                    red: style.normalColor.red,
                    green: style.normalColor.green,
                    blue: style.normalColor.blue,
                    alpha: style.normalColor.alpha
                )
            ]
            line.text.draw(at: CGPoint(x: x, y: y), withAttributes: normalAttrs)

            // Draw highlighted part
            let highlightWidth = textSize.width * CGFloat(progress)

            cgContext.saveGState()
            cgContext.clip(to: CGRect(x: x, y: y, width: highlightWidth, height: textSize.height))

            let highlightAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(
                    red: style.highlightColor.red,
                    green: style.highlightColor.green,
                    blue: style.highlightColor.blue,
                    alpha: style.highlightColor.alpha
                )
            ]
            line.text.draw(at: CGPoint(x: x, y: y), withAttributes: highlightAttrs)

            cgContext.restoreGState()
        }

        return CIImage(image: image)
        #else
        return nil
        #endif
    }
}

// MARK: - 3D Text

struct Text3D: Identifiable, Codable {
    let id: UUID
    var text: String
    var font: String
    var fontSize: CGFloat
    var depth: CGFloat
    var bevel: CGFloat
    var rotation: SIMD3<Float>
    var color: CodableColor
    var lightingIntensity: Float
    var shadowEnabled: Bool

    init(
        id: UUID = UUID(),
        text: String,
        font: String = "Helvetica-Bold",
        fontSize: CGFloat = 72,
        depth: CGFloat = 30,
        bevel: CGFloat = 5,
        rotation: SIMD3<Float> = SIMD3(15, -20, 0),
        color: CodableColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
        lightingIntensity: Float = 1.0,
        shadowEnabled: Bool = true
    ) {
        self.id = id
        self.text = text
        self.font = font
        self.fontSize = fontSize
        self.depth = depth
        self.bevel = bevel
        self.rotation = rotation
        self.color = color
        self.lightingIntensity = lightingIntensity
        self.shadowEnabled = shadowEnabled
    }
}

// Use Title3DRenderer for rendering (implemented in EffectsEnhanced)

// MARK: - Handwriting Animation

struct HandwritingAnimation: Identifiable, Codable {
    let id: UUID
    var text: String
    var font: String
    var fontSize: CGFloat
    var color: CodableColor
    var strokeWidth: CGFloat
    var duration: Double
    var style: HandwritingStyle

    init(
        id: UUID = UUID(),
        text: String,
        font: String = "Bradley Hand",
        fontSize: CGFloat = 48,
        color: CodableColor = CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
        strokeWidth: CGFloat = 2,
        duration: Double = 3.0,
        style: HandwritingStyle = .natural
    ) {
        self.id = id
        self.text = text
        self.font = font
        self.fontSize = fontSize
        self.color = color
        self.strokeWidth = strokeWidth
        self.duration = duration
        self.style = style
    }
}

enum HandwritingStyle: String, Codable, CaseIterable {
    case natural = "Natural"
    case neat = "Neat"
    case calligraphy = "Calligraphy"
    case childish = "Childish"
}

class HandwritingRenderer: ObservableObject {
    static let shared = HandwritingRenderer()

    private init() {}

    // Render handwriting animation frame
    func render(_ animation: HandwritingAnimation, progress: Double, size: CGSize) -> CIImage? {
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext

            // Get text path
            let font = UIFont(name: animation.font, size: animation.fontSize) ?? UIFont.systemFont(ofSize: animation.fontSize)

            let attrString = NSAttributedString(string: animation.text, attributes: [.font: font])
            let line = CTLineCreateWithAttributedString(attrString)
            let runs = CTLineGetGlyphRuns(line) as! [CTRun]

            var fullPath = CGMutablePath()

            for run in runs {
                let runFont = (CTRunGetAttributes(run) as Dictionary)[kCTFontAttributeName] as! CTFont
                let glyphCount = CTRunGetGlyphCount(run)

                for i in 0..<glyphCount {
                    let range = CFRange(location: i, length: 1)
                    var glyph = CGGlyph()
                    var position = CGPoint()

                    CTRunGetGlyphs(run, range, &glyph)
                    CTRunGetPositions(run, range, &position)

                    if let glyphPath = CTFontCreatePathForGlyph(runFont, glyph, nil) {
                        var transform = CGAffineTransform(translationX: position.x + size.width / 2 - CGFloat(animation.text.count) * animation.fontSize / 4,
                                                         y: size.height / 2)
                        fullPath.addPath(glyphPath, transform: transform)
                    }
                }
            }

            // Calculate path length to draw
            let totalLength = pathLength(fullPath)
            let drawLength = totalLength * CGFloat(progress)

            // Set drawing style
            cgContext.setStrokeColor(CGColor(
                red: animation.color.red,
                green: animation.color.green,
                blue: animation.color.blue,
                alpha: animation.color.alpha
            ))
            cgContext.setLineWidth(animation.strokeWidth)
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)

            // Draw partial path
            let partialPath = createPartialPath(fullPath, length: drawLength)
            cgContext.addPath(partialPath)
            cgContext.strokePath()
        }

        return CIImage(image: image)
        #else
        return nil
        #endif
    }

    private func pathLength(_ path: CGPath) -> CGFloat {
        var length: CGFloat = 0
        var previousPoint: CGPoint?

        path.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                previousPoint = points[0]
            case .addLineToPoint:
                if let prev = previousPoint {
                    length += hypot(points[0].x - prev.x, points[0].y - prev.y)
                }
                previousPoint = points[0]
            case .addQuadCurveToPoint:
                // Simplified: approximate with straight line
                if let prev = previousPoint {
                    length += hypot(points[1].x - prev.x, points[1].y - prev.y)
                }
                previousPoint = points[1]
            case .addCurveToPoint:
                if let prev = previousPoint {
                    length += hypot(points[2].x - prev.x, points[2].y - prev.y)
                }
                previousPoint = points[2]
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }

        return length
    }

    private func createPartialPath(_ fullPath: CGPath, length: CGFloat) -> CGPath {
        let partialPath = CGMutablePath()
        var currentLength: CGFloat = 0
        var previousPoint: CGPoint?

        fullPath.applyWithBlock { element in
            guard currentLength < length else { return }

            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                partialPath.move(to: points[0])
                previousPoint = points[0]
            case .addLineToPoint:
                if let prev = previousPoint {
                    let segmentLength = hypot(points[0].x - prev.x, points[0].y - prev.y)
                    if currentLength + segmentLength <= length {
                        partialPath.addLine(to: points[0])
                        currentLength += segmentLength
                    } else {
                        let remaining = length - currentLength
                        let ratio = remaining / segmentLength
                        let endPoint = CGPoint(
                            x: prev.x + (points[0].x - prev.x) * ratio,
                            y: prev.y + (points[0].y - prev.y) * ratio
                        )
                        partialPath.addLine(to: endPoint)
                        currentLength = length
                    }
                }
                previousPoint = points[0]
            case .addQuadCurveToPoint:
                partialPath.addQuadCurve(to: points[1], control: points[0])
                previousPoint = points[1]
            case .addCurveToPoint:
                partialPath.addCurve(to: points[2], control1: points[0], control2: points[1])
                previousPoint = points[2]
            case .closeSubpath:
                partialPath.closeSubpath()
            @unknown default:
                break
            }
        }

        return partialPath
    }
}

// MARK: - Danmaku Subtitles

struct Danmaku: Identifiable, Codable {
    let id: UUID
    var text: String
    var type: DanmakuType
    var color: CodableColor
    var fontSize: CGFloat
    var startTime: CMTime
    var duration: Double
    var position: CGFloat  // 0-1, vertical position
    var speed: CGFloat

    init(
        id: UUID = UUID(),
        text: String,
        type: DanmakuType = .scroll,
        color: CodableColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
        fontSize: CGFloat = 24,
        startTime: CMTime = .zero,
        duration: Double = 5.0,
        position: CGFloat = 0.5,
        speed: CGFloat = 1.0
    ) {
        self.id = id
        self.text = text
        self.type = type
        self.color = color
        self.fontSize = fontSize
        self.startTime = startTime
        self.duration = duration
        self.position = position
        self.speed = speed
    }
}

enum DanmakuType: String, Codable, CaseIterable {
    case scroll = "Scroll"
    case top = "Top Fixed"
    case bottom = "Bottom Fixed"
}

class DanmakuRenderer: ObservableObject {
    static let shared = DanmakuRenderer()

    @Published var danmakus: [Danmaku] = []
    @Published var isEnabled = true
    @Published var opacity: Float = 1.0
    @Published var density: Float = 1.0  // Danmaku density

    private init() {}

    // Add danmaku
    func addDanmaku(_ danmaku: Danmaku) {
        danmakus.append(danmaku)
    }

    // Load danmaku from file
    func loadFromFile(url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        // Parse danmaku file format (e.g., Bilibili danmaku XML)
        danmakus = parseDanmakuXML(content)
    }

    private func parseDanmakuXML(_ xml: String) -> [Danmaku] {
        // Simplified implementation
        return []
    }

    // Render danmaku layer
    func render(at time: CMTime, size: CGSize) -> CIImage? {
        guard isEnabled else { return nil }

        let activeDanmakus = danmakus.filter { danmaku in
            let startSeconds = CMTimeGetSeconds(danmaku.startTime)
            let endSeconds = startSeconds + danmaku.duration
            let currentSeconds = CMTimeGetSeconds(time)
            return currentSeconds >= startSeconds && currentSeconds <= endSeconds
        }

        guard !activeDanmakus.isEmpty else { return nil }

        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            for danmaku in activeDanmakus {
                let progress = (CMTimeGetSeconds(time) - CMTimeGetSeconds(danmaku.startTime)) / danmaku.duration
                renderSingleDanmaku(danmaku, progress: progress, size: size, context: context.cgContext)
            }
        }

        var ciImage = CIImage(image: image)

        // Apply opacity
        if opacity < 1.0, let opacityFilter = CIFilter(name: "CIColorMatrix") {
            opacityFilter.setValue(ciImage, forKey: kCIInputImageKey)
            opacityFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity)), forKey: "inputAVector")
            ciImage = opacityFilter.outputImage
        }

        return ciImage
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    private func renderSingleDanmaku(_ danmaku: Danmaku, progress: Double, size: CGSize, context: CGContext) {
        let font = UIFont.systemFont(ofSize: danmaku.fontSize, weight: .medium)
        let textSize = danmaku.text.size(withAttributes: [.font: font])

        var x: CGFloat
        let y: CGFloat

        switch danmaku.type {
        case .scroll:
            // Scroll from right to left
            x = size.width - (size.width + textSize.width) * CGFloat(progress) * danmaku.speed
            y = size.height * danmaku.position
        case .top:
            x = (size.width - textSize.width) / 2
            y = size.height * 0.1
        case .bottom:
            x = (size.width - textSize.width) / 2
            y = size.height * 0.85
        }

        // Draw stroke
        let strokeAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .strokeColor: UIColor.black,
            .strokeWidth: -2
        ]
        danmaku.text.draw(at: CGPoint(x: x, y: y), withAttributes: strokeAttrs)

        // Draw text
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(
                red: danmaku.color.red,
                green: danmaku.color.green,
                blue: danmaku.color.blue,
                alpha: danmaku.color.alpha
            )
        ]
        danmaku.text.draw(at: CGPoint(x: x, y: y), withAttributes: textAttrs)
    }
    #endif
}

// MARK: - Path Text

struct PathText: Identifiable, Codable {
    let id: UUID
    var text: String
    var font: String
    var fontSize: CGFloat
    var color: CodableColor
    var pathType: TextPathType
    var customPath: [CGPoint]?
    var offset: CGFloat  // Offset along path
    var animated: Bool
    var animationDuration: Double

    init(
        id: UUID = UUID(),
        text: String,
        font: String = "Helvetica",
        fontSize: CGFloat = 36,
        color: CodableColor = CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
        pathType: TextPathType = .wave,
        customPath: [CGPoint]? = nil,
        offset: CGFloat = 0,
        animated: Bool = false,
        animationDuration: Double = 3.0
    ) {
        self.id = id
        self.text = text
        self.font = font
        self.fontSize = fontSize
        self.color = color
        self.pathType = pathType
        self.customPath = customPath
        self.offset = offset
        self.animated = animated
        self.animationDuration = animationDuration
    }
}

enum TextPathType: String, Codable, CaseIterable {
    case wave = "Wave"
    case circle = "Circle"
    case arc = "Arc"
    case spiral = "Spiral"
    case heart = "Heart"
    case custom = "Custom"
}

class PathTextRenderer: ObservableObject {
    static let shared = PathTextRenderer()

    private init() {}

    // Generate path
    func generatePath(type: TextPathType, size: CGSize) -> CGPath {
        let path = CGMutablePath()

        switch type {
        case .wave:
            let amplitude: CGFloat = 30
            let frequency: CGFloat = 2
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            for x in stride(from: 0, to: size.width, by: 5) {
                let y = size.height / 2 + amplitude * sin(x / size.width * frequency * 2 * .pi)
                path.addLine(to: CGPoint(x: x, y: y))
            }

        case .circle:
            let radius = min(size.width, size.height) * 0.35
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

        case .arc:
            let center = CGPoint(x: size.width / 2, y: size.height * 0.7)
            let radius = size.width * 0.4
            path.addArc(center: center, radius: radius, startAngle: .pi, endAngle: 0, clockwise: false)

        case .spiral:
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            var radius: CGFloat = 10
            var angle: CGFloat = 0
            path.move(to: CGPoint(x: center.x + radius, y: center.y))
            while radius < min(size.width, size.height) / 2 {
                angle += 0.1
                radius += 0.5
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                path.addLine(to: CGPoint(x: x, y: y))
            }

        case .heart:
            let scale: CGFloat = min(size.width, size.height) * 0.3
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            path.move(to: CGPoint(x: center.x, y: center.y + scale * 0.3))
            for t in stride(from: 0, to: 2 * Double.pi, by: 0.1) {
                let x = center.x + scale * 16 * pow(sin(t), 3) / 16
                let y = center.y - scale * (13 * cos(t) - 5 * cos(2*t) - 2 * cos(3*t) - cos(4*t)) / 16
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.closeSubpath()

        case .custom:
            break
        }

        return path
    }

    // Render path text
    func render(_ pathText: PathText, time: Double, size: CGSize) -> CIImage? {
        let path = generatePath(type: pathText.pathType, size: size)

        var offset = pathText.offset
        if pathText.animated {
            offset += CGFloat(time.truncatingRemainder(dividingBy: pathText.animationDuration) / pathText.animationDuration)
        }

        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext

            let font = UIFont(name: pathText.font, size: pathText.fontSize) ?? UIFont.systemFont(ofSize: pathText.fontSize)

            // Draw each character along the path
            let pathLength = self.pathLength(path)
            let charSpacing = pathLength / CGFloat(pathText.text.count + 1)

            for (index, char) in pathText.text.enumerated() {
                let charOffset = (CGFloat(index + 1) / CGFloat(pathText.text.count + 1) + offset).truncatingRemainder(dividingBy: 1.0)
                let point = pointOnPath(path, at: charOffset * pathLength)
                let angle = angleOnPath(path, at: charOffset * pathLength)

                cgContext.saveGState()
                cgContext.translateBy(x: point.x, y: point.y)
                cgContext.rotate(by: angle)

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor(
                        red: pathText.color.red,
                        green: pathText.color.green,
                        blue: pathText.color.blue,
                        alpha: pathText.color.alpha
                    )
                ]

                String(char).draw(at: CGPoint(x: -pathText.fontSize / 2, y: -pathText.fontSize / 2), withAttributes: attrs)

                cgContext.restoreGState()
            }
        }

        return CIImage(image: image)
        #else
        return nil
        #endif
    }

    private func pathLength(_ path: CGPath) -> CGFloat {
        // Simplified calculation
        var length: CGFloat = 0
        var previousPoint: CGPoint?

        path.applyWithBlock { element in
            let points = element.pointee.points
            if element.pointee.type == .addLineToPoint, let prev = previousPoint {
                length += hypot(points[0].x - prev.x, points[0].y - prev.y)
            }
            previousPoint = points[0]
        }

        return max(length, 1)
    }

    private func pointOnPath(_ path: CGPath, at distance: CGFloat) -> CGPoint {
        var currentDistance: CGFloat = 0
        var previousPoint: CGPoint?
        var result = CGPoint.zero

        path.applyWithBlock { element in
            guard currentDistance < distance else { return }

            let points = element.pointee.points
            if element.pointee.type == .moveToPoint {
                previousPoint = points[0]
            } else if element.pointee.type == .addLineToPoint, let prev = previousPoint {
                let segmentLength = hypot(points[0].x - prev.x, points[0].y - prev.y)
                if currentDistance + segmentLength >= distance {
                    let remaining = distance - currentDistance
                    let ratio = remaining / segmentLength
                    result = CGPoint(
                        x: prev.x + (points[0].x - prev.x) * ratio,
                        y: prev.y + (points[0].y - prev.y) * ratio
                    )
                }
                currentDistance += segmentLength
                previousPoint = points[0]
            }
        }

        return result
    }

    private func angleOnPath(_ path: CGPath, at distance: CGFloat) -> CGFloat {
        var currentDistance: CGFloat = 0
        var previousPoint: CGPoint?
        var angle: CGFloat = 0

        path.applyWithBlock { element in
            guard currentDistance < distance else { return }

            let points = element.pointee.points
            if element.pointee.type == .moveToPoint {
                previousPoint = points[0]
            } else if element.pointee.type == .addLineToPoint, let prev = previousPoint {
                let segmentLength = hypot(points[0].x - prev.x, points[0].y - prev.y)
                if currentDistance + segmentLength >= distance {
                    angle = atan2(points[0].y - prev.y, points[0].x - prev.x)
                }
                currentDistance += segmentLength
                previousPoint = points[0]
            }
        }

        return angle
    }
}

// MARK: - Subtitle Translation

class SubtitleTranslator: ObservableObject {
    static let shared = SubtitleTranslator()

    @Published var isTranslating = false
    @Published var supportedLanguages = [
        ("zh", "Chinese"),
        ("en", "English"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("fr", "French"),
        ("de", "German"),
        ("es", "Spanish"),
        ("ru", "Russian"),
        ("ar", "Arabic")
    ]

    private init() {}

    // Translate subtitles
    func translate(
        subtitles: [TextOverlay],
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> [TextOverlay] {
        isTranslating = true
        defer { isTranslating = false }

        var translated: [TextOverlay] = []

        for subtitle in subtitles {
            var newSubtitle = subtitle
            newSubtitle.text = try await translateText(subtitle.text, from: sourceLanguage, to: targetLanguage)
            translated.append(newSubtitle)
        }

        return translated
    }

    private func translateText(_ text: String, from: String, to: String) async throws -> String {
        // Call translation API
        // Simplified implementation: return original text
        return text
    }

    // Export bilingual subtitles
    func exportBilingual(
        original: [TextOverlay],
        translated: [TextOverlay],
        format: SubtitleFormat
    ) -> String {
        var result = ""

        for (index, (orig, trans)) in zip(original, translated).enumerated() {
            switch format {
            case .srt:
                result += "\(index + 1)\n"
                result += formatSRTTime(orig.timeRange.start) + " --> " + formatSRTTime(CMTimeAdd(orig.timeRange.start, orig.timeRange.duration)) + "\n"
                result += orig.text + "\n"
                result += trans.text + "\n\n"
            default:
                break
            }
        }

        return result
    }

    private func formatSRTTime(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
    }

    enum SubtitleFormat {
        case srt, vtt
    }
}

// MARK: - Subtitle Templates

struct SubtitleTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: String
    var style: TextStyle
    var animation: TextAnimation
    var previewImage: String?

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        style: TextStyle,
        animation: TextAnimation,
        previewImage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.style = style
        self.animation = animation
        self.previewImage = previewImage
    }
}

class SubtitleTemplateManager: ObservableObject {
    static let shared = SubtitleTemplateManager()

    @Published var templates: [SubtitleTemplate] = []
    @Published var categories = ["Basic", "Social", "Vlog", "Cinema", "News", "Entertainment", "Tutorial"]

    private init() {
        loadBuiltInTemplates()
    }

    private func loadBuiltInTemplates() {
        templates = [
            SubtitleTemplate(
                name: "Clean White Text",
                category: "Basic",
                style: TextStyle(fontName: "PingFang SC", fontSize: 32, textColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 1)),
                animation: .fadeIn
            ),
            SubtitleTemplate(
                name: "Yellow Outline",
                category: "Basic",
                style: TextStyle(fontName: "PingFang SC", fontSize: 36, textColor: CodableColor(red: 1, green: 0.9, blue: 0, alpha: 1), strokeColor: CodableColor(red: 0, green: 0, blue: 0, alpha: 1), strokeWidth: 2),
                animation: .fadeIn
            ),
            SubtitleTemplate(
                name: "Social Media Trending",
                category: "Social",
                style: TextStyle(fontName: "PingFang SC", fontSize: 40, textColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 1), backgroundColor: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.7)),
                animation: .pop
            ),
            SubtitleTemplate(
                name: "Movie Subtitle",
                category: "Cinema",
                style: TextStyle(fontName: "STSong", fontSize: 28, textColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 1)),
                animation: .fadeIn
            ),
            SubtitleTemplate(
                name: "News Title",
                category: "News",
                style: TextStyle(fontName: "PingFang SC", fontSize: 48, textColor: CodableColor(red: 1, green: 0, blue: 0, alpha: 1), backgroundColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 0.9)),
                animation: .slideFromBottom
            ),
        ]
    }

    func filterByCategory(_ category: String) -> [SubtitleTemplate] {
        if category == "All" {
            return templates
        }
        return templates.filter { $0.category == category }
    }
}

#if canImport(UIKit)
import UIKit
#endif
