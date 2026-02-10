import Foundation

/// Represents a caption/subtitle entry (compatible with SRT format)
public struct Caption: Codable, Identifiable, Sendable {
    public var id: UUID
    public var index: Int
    public var startTime: Double // seconds
    public var endTime: Double // seconds
    public var text: String
    
    public init(
        id: UUID = UUID(),
        index: Int = 0,
        startTime: Double,
        endTime: Double,
        text: String
    ) {
        self.id = id
        self.index = index
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
    
    public var duration: Double {
        endTime - startTime
    }
}

/// Manages a collection of captions (SRT import/export)
public struct CaptionTrack: Codable, Sendable {
    public var captions: [Caption]
    
    public init(captions: [Caption] = []) {
        self.captions = captions
    }
    
    /// Parse SRT formatted string into captions
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
    
    /// Export captions to SRT formatted string
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
    
    /// Get captions visible at a given time
    public func captions(at time: Double) -> [Caption] {
        captions.filter { time >= $0.startTime && time <= $0.endTime }
    }
    
    // MARK: - Private Helpers
    
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
    
    private func formatSRTTime(_ time: Double) -> String {
        let hours = Int(time / 3600)
        let minutes = Int((time.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = time.truncatingRemainder(dividingBy: 60)
        let wholeSeconds = Int(seconds)
        let milliseconds = Int((seconds - Double(wholeSeconds)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, wholeSeconds, milliseconds)
    }
}
