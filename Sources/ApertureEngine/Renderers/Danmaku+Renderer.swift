//
//  DanmakuRenderer.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import SwiftUI

public actor DanmakuRenderer {
    static let shared = DanmakuRenderer()

    var danmakus: [Danmaku] = []
    var isEnabled = true
    var opacity: Float = 1.0
    var density: Float = 1.0  // Danmaku density

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
