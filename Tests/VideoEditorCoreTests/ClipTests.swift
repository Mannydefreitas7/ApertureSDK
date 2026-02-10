import Foundation
import Testing
@testable import VideoEditorCore

struct ClipTests {
    
    @Test func clipInitialization() {
        let clip = Clip(
            type: .video,
            timeRange: ClipTimeRange(start: 0, duration: 10),
            sourceURL: URL(string: "file:///test.mp4")
        )
        
        #expect(clip.type == Clip.ClipType.video)
        #expect(clip.timeRange.start == 0)
        #expect(clip.timeRange.duration == 10)
        #expect(clip.opacity == 1.0)
        #expect(clip.volume == 1.0)
        #expect(clip.transform == ClipTransform.identity)
        #expect(clip.effects.isEmpty)
        #expect(!clip.isMuted)
    }
    
    @Test func clipTrim() {
        var clip = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 10))
        
        clip.trim(start: 2, duration: 5)
        #expect(clip.timeRange.start == 2)
        #expect(clip.timeRange.duration == 5)
    }
    
    @Test func clipSplit() throws {
        let clip = Clip(
            type: .video,
            timeRange: ClipTimeRange(start: 0, duration: 10),
            sourceURL: URL(string: "file:///test.mp4")
        )
        
        let (first, second) = try #require(clip.split(at: 4), "Split should succeed")
        
        #expect(first.timeRange.start == 0)
        #expect(first.timeRange.duration == 4)
        #expect(second.timeRange.start == 4)
        #expect(second.timeRange.duration == 6)
        
        // IDs should be different
        #expect(first.id != second.id)
        #expect(first.id != clip.id)
    }
    
    @Test func clipSplitAtInvalidOffset() {
        let clip = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 10))
        
        // Split at 0 should fail
        #expect(clip.split(at: 0) == nil)
        
        // Split at or past duration should fail
        #expect(clip.split(at: 10) == nil)
        #expect(clip.split(at: 15) == nil)
    }
    
    @Test func clipTypes() {
        #expect(Clip(type: .video, timeRange: .zero).type == .video)
        #expect(Clip(type: .audio, timeRange: .zero).type == .audio)
        #expect(Clip(type: .image, timeRange: .zero).type == .image)
        #expect(Clip(type: .text, timeRange: .zero).type == .text)
    }
    
    @Test func clipCodable() throws {
        let clip = Clip(
            type: .video,
            timeRange: ClipTimeRange(start: 2, duration: 8),
            sourceURL: URL(string: "file:///video.mp4"),
            opacity: 0.8,
            volume: 0.5,
            effects: [.brightness(0.3), .contrast(1.2)],
            isMuted: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(clip)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Clip.self, from: data)
        
        #expect(decoded.type == Clip.ClipType.video)
        #expect(decoded.timeRange.start == 2)
        #expect(decoded.timeRange.duration == 8)
        #expect(decoded.opacity == 0.8)
        #expect(decoded.volume == 0.5)
        #expect(decoded.effects.count == 2)
        #expect(decoded.isMuted)
    }
}
