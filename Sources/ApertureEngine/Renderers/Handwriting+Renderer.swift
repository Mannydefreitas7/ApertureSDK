//
//  HandwritingRenderer.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import SwiftUI

public actor HandwritingRenderer {
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
