import Foundation

/// Represents a caption/subtitle entry (compatible with SRT format)
public struct Caption: Identifiable {
    public var id: UUID = UUID()
    public var index: Int
    public var startTime: Double // seconds
    public var endTime: Double // seconds
    public var text: String
    
    public var duration: Double {
        endTime - startTime
    }
}

/// Manages a collection of captions (SRT import/export)
public struct CaptionTrack: Identifiable {
    public var id: UUID
    public var captions: [Caption]
    
    public init(captions: [Caption] = []) {
        self.captions = captions
        self.id = UUID()
    }
}
