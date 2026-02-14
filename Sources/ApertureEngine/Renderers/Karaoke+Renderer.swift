//
//  KaraokeRenderer.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import SwiftUI

public actor KaraokeRenderer {
    static let shared = KaraokeRenderer()

    var currentSubtitle: KaraokeSubtitle?

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
