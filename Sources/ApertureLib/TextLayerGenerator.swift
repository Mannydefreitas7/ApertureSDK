//
//  TextLayerGenerator.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import Foundation
import CoreGraphics
import AVFoundation
import QuartzCore

actor TextLayerGenerator {

    static let shared = TextLayerGenerator()

    private init() {}

     func createTextLayer(
        for overlay: UnifiedTextOverlay,
        videoSize: CGSize
    ) -> CATextLayer {
        let textLayer = CATextLayer()

        textLayer.string = overlay.text
        textLayer.font = overlay.style.font
        textLayer.fontSize = overlay.style.fontSize
        textLayer.foregroundColor = overlay.style.textColor.cgColor

        switch overlay.style.alignment {
            case .left: textLayer.alignmentMode = .left
            case .center: textLayer.alignmentMode = .center
            case .right: textLayer.alignmentMode = .right
        }

        let textSize = calculateTextSize(overlay.text, style: overlay.style, maxWidth: videoSize.width * 0.9)
        textLayer.frame = CGRect(origin: .zero, size: textSize)

        let normalizedPos = overlay.position.normalizedPosition(in: videoSize, textSize: textSize)
        textLayer.position = CGPoint(
            x: normalizedPos.x * videoSize.width + textSize.width / 2,
            y: normalizedPos.y * videoSize.height + textSize.height / 2
        )

        if let bgColor = overlay.style.backgroundColor {
            textLayer.backgroundColor = bgColor.cgColor
            textLayer.cornerRadius = 4
        }

        if let shadowColor = overlay.style.shadowColor {
            textLayer.shadowColor = shadowColor.cgColor
            textLayer.shadowOffset = overlay.style.shadowOffset
            textLayer.shadowRadius = overlay.style.shadowBlur
            textLayer.shadowOpacity = 1.0
        }

        textLayer.contentsScale = 2.0
        textLayer.isWrapped = true
        textLayer.truncationMode = .end

        return textLayer
    }

     func calculateTextSize(_ text: String, style: TextStyle, maxWidth: CGFloat) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.font
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        return CGSize(
            width: ceil(boundingRect.width) + 20,
            height: ceil(boundingRect.height) + 10
        )
    }

     func addAnimation(
        to layer: CATextLayer,
        animation: TextAnimation,
        duration: CFTimeInterval,
        timeRange: CMTimeRange
    ) {
        let startTime = CMTimeGetSeconds(timeRange.start)
        let endTime = CMTimeGetSeconds(timeRange.end)
        let clipDuration = endTime - startTime
        let animDuration = min(0.5, clipDuration / 2) // 动画时长最多0.5秒

        switch animation {
            case .none:
                break

            case .fadeIn:
                let fadeIn = CABasicAnimation(keyPath: "opacity")
                fadeIn.fromValue = 0
                fadeIn.toValue = 1
                fadeIn.duration = animDuration
                fadeIn.beginTime = startTime
                fadeIn.fillMode = .forwards
                fadeIn.isRemovedOnCompletion = false
                layer.add(fadeIn, forKey: "fadeIn")

            case .fadeOut:
                let fadeOut = CABasicAnimation(keyPath: "opacity")
                fadeOut.fromValue = 1
                fadeOut.toValue = 0
                fadeOut.duration = animDuration
                fadeOut.beginTime = endTime - animDuration
                fadeOut.fillMode = .forwards
                fadeOut.isRemovedOnCompletion = false
                layer.add(fadeOut, forKey: "fadeOut")

            case .fadeInOut:
                let fadeIn = CABasicAnimation(keyPath: "opacity")
                fadeIn.fromValue = 0
                fadeIn.toValue = 1
                fadeIn.duration = animDuration
                fadeIn.beginTime = startTime
                layer.add(fadeIn, forKey: "fadeIn")

                let fadeOut = CABasicAnimation(keyPath: "opacity")
                fadeOut.fromValue = 1
                fadeOut.toValue = 0
                fadeOut.duration = animDuration
                fadeOut.beginTime = endTime - animDuration
                fadeOut.fillMode = .forwards
                fadeOut.isRemovedOnCompletion = false
                layer.add(fadeOut, forKey: "fadeOut")

            case .slideUp:
                let slideUp = CABasicAnimation(keyPath: "position.y")
                slideUp.fromValue = layer.position.y - 100
                slideUp.toValue = layer.position.y
                slideUp.duration = animDuration
                slideUp.beginTime = startTime
                slideUp.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(slideUp, forKey: "slideUp")

            case .slideDown:
                let slideDown = CABasicAnimation(keyPath: "position.y")
                slideDown.fromValue = layer.position.y + 100
                slideDown.toValue = layer.position.y
                slideDown.duration = animDuration
                slideDown.beginTime = startTime
                slideDown.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(slideDown, forKey: "slideDown")

            case .slideLeft:
                let slide = CABasicAnimation(keyPath: "position.x")
                slide.fromValue = layer.position.x + 100
                slide.toValue = layer.position.x
                slide.duration = animDuration
                slide.beginTime = startTime
                slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(slide, forKey: "slideLeft")

            case .slideRight:
                let slide = CABasicAnimation(keyPath: "position.x")
                slide.fromValue = layer.position.x - 100
                slide.toValue = layer.position.x
                slide.duration = animDuration
                slide.beginTime = startTime
                slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(slide, forKey: "slideRight")

            case .scale:
                let scale = CABasicAnimation(keyPath: "transform.scale")
                scale.fromValue = 0.5
                scale.toValue = 1.0
                scale.duration = animDuration
                scale.beginTime = startTime
                scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(scale, forKey: "scale")

            case .bounce:
                let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
                bounce.values = [0.5, 1.2, 0.9, 1.05, 1.0]
                bounce.keyTimes = [0, 0.4, 0.6, 0.8, 1.0]
                bounce.duration = animDuration * 1.5
                bounce.beginTime = startTime
                layer.add(bounce, forKey: "bounce")

            case .typewriter:
                break

            case .slideFromBottom:
                let slide = CABasicAnimation(keyPath: "position.y")
                slide.fromValue = layer.position.y + 200
                slide.toValue = layer.position.y
                slide.duration = animDuration
                slide.beginTime = startTime
                slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(slide, forKey: "slideFromBottom")

            case .pop:
                let pop = CAKeyframeAnimation(keyPath: "transform.scale")
                pop.values = [0, 1.2, 1.0]
                pop.keyTimes = [0, 0.6, 1.0]
                pop.duration = animDuration
                pop.beginTime = startTime
                pop.timingFunction = CAMediaTimingFunction(name: .easeOut)
                layer.add(pop, forKey: "pop")
        }
    }
}
