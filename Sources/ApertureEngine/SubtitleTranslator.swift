//
//  SubtitleTranslator.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import SwiftUI

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
