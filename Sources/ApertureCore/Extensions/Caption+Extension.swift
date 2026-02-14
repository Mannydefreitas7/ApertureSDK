//
//  Caption+Extension.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation

extension CaptionTrack {
    /// Parses an SRT formatted string into a caption track.
    ///
    /// - Parameter srtString: The raw SRT text to parse.
    /// - Returns: A `CaptionTrack` containing captions extracted from the input.
    ///
    /// Example:
    /// ```
    /// let track = CaptionTrack.fromSRT(srtString)
    /// ```
    public static func fromSRT(_ srtString: String) -> CaptionTrack {
        var captions: [Caption] = []
        let blocks = srtString.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }

            guard let index = Int(lines[0].trimmingCharacters(in: .whitespaces)) else { continue }

            let timeParts = lines[1].components(separatedBy: " --> ")
            guard timeParts.count == 2 else { continue }

            let startTime = parseSRTTime(timeParts[0].trimmingCharacters(in: .whitespaces))
            let endTime = parseSRTTime(timeParts[1].trimmingCharacters(in: .whitespaces))

            let text = lines[2...].joined(separator: "\n")

            let caption = Caption(
                index: index,
                startTime: startTime,
                endTime: endTime,
                text: text
            )
            captions.append(caption)
        }

        return CaptionTrack(captions: captions)
    }

    /// Exports the captions as an SRT formatted string.
    ///
    /// - Returns: A string formatted according to the SRT specification.
    public func toSRT() -> String {
        let sortedCaptions = captions.sorted { $0.startTime < $1.startTime }
        var result = ""

        for (idx, caption) in sortedCaptions.enumerated() {
            if idx > 0 { result += "\n" }
            result += "\(idx + 1)\n"
            result += "\(formatSRTTime(caption.startTime)) --> \(formatSRTTime(caption.endTime))\n"
            result += caption.text + "\n"
        }

        return result
    }

    /// Returns captions visible at a given time.
    ///
    /// - Parameter time: Time in seconds to query.
    /// - Returns: Captions whose time range contains the provided time.
    public func captions(at time: Double) -> [Caption] {
        captions.filter { time >= $0.startTime && time < $0.endTime }
    }

        // MARK: - Private Helpers
    /// Parses an SRT time string in the form `HH:MM:SS,mmm` into seconds.
    ///
    /// - Parameter timeString: The SRT time string to parse.
    /// - Returns: Time in seconds, or `0` if the input is malformed.
    private static func parseSRTTime(_ timeString: String) -> Double {
            // Format: HH:MM:SS,mmm
        let cleaned = timeString.replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.components(separatedBy: ":")
        guard parts.count == 3 else { return 0 }

        let hours = Double(parts[0]) ?? 0
        let minutes = Double(parts[1]) ?? 0
        let seconds = Double(parts[2]) ?? 0

        return hours * 3600 + minutes * 60 + seconds
    }

    /// Formats a time interval into an SRT time string.
    ///
    /// - Parameter time: Time in seconds.
    /// - Returns: A string in the form `HH:MM:SS,mmm`.
    private func formatSRTTime(_ time: Double) -> String {
        let hours = Int(time / 3600)
        let minutes = Int((time.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = time.truncatingRemainder(dividingBy: 60)
        let wholeSeconds = Int(seconds)
        let milliseconds = Int((seconds - Double(wholeSeconds)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, wholeSeconds, milliseconds)
    }

}
