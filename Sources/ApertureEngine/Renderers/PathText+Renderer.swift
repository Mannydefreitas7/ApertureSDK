//
//  PathTextRenderer.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import SwiftUI

public actor PathTextRenderer {
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

