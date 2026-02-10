import XCTest
@testable import VideoEditorCore

final class ClipTests: XCTestCase {
    
    func testClipInitialization() {
        let clip = Clip(
            type: .video,
            timeRange: ClipTimeRange(start: 0, duration: 10),
            sourceURL: URL(string: "file:///test.mp4")
        )
        
        XCTAssertEqual(clip.type, .video)
        XCTAssertEqual(clip.timeRange.start, 0)
        XCTAssertEqual(clip.timeRange.duration, 10)
        XCTAssertEqual(clip.opacity, 1.0)
        XCTAssertEqual(clip.volume, 1.0)
        XCTAssertEqual(clip.transform, .identity)
        XCTAssertTrue(clip.effects.isEmpty)
        XCTAssertFalse(clip.isMuted)
    }
    
    func testClipTrim() {
        var clip = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 10))
        
        clip.trim(start: 2, duration: 5)
        XCTAssertEqual(clip.timeRange.start, 2)
        XCTAssertEqual(clip.timeRange.duration, 5)
    }
    
    func testClipSplit() {
        let clip = Clip(
            type: .video,
            timeRange: ClipTimeRange(start: 0, duration: 10),
            sourceURL: URL(string: "file:///test.mp4")
        )
        
        guard let (first, second) = clip.split(at: 4) else {
            XCTFail("Split should succeed")
            return
        }
        
        XCTAssertEqual(first.timeRange.start, 0)
        XCTAssertEqual(first.timeRange.duration, 4)
        XCTAssertEqual(second.timeRange.start, 4)
        XCTAssertEqual(second.timeRange.duration, 6)
        
        // IDs should be different
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNotEqual(first.id, clip.id)
    }
    
    func testClipSplitAtInvalidOffset() {
        let clip = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 10))
        
        // Split at 0 should fail
        XCTAssertNil(clip.split(at: 0))
        
        // Split at or past duration should fail
        XCTAssertNil(clip.split(at: 10))
        XCTAssertNil(clip.split(at: 15))
    }
    
    func testClipTypes() {
        XCTAssertEqual(Clip(type: .video, timeRange: .zero).type, .video)
        XCTAssertEqual(Clip(type: .audio, timeRange: .zero).type, .audio)
        XCTAssertEqual(Clip(type: .image, timeRange: .zero).type, .image)
        XCTAssertEqual(Clip(type: .text, timeRange: .zero).type, .text)
    }
    
    func testClipCodable() throws {
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
        
        XCTAssertEqual(decoded.type, .video)
        XCTAssertEqual(decoded.timeRange.start, 2)
        XCTAssertEqual(decoded.timeRange.duration, 8)
        XCTAssertEqual(decoded.opacity, 0.8)
        XCTAssertEqual(decoded.volume, 0.5)
        XCTAssertEqual(decoded.effects.count, 2)
        XCTAssertTrue(decoded.isMuted)
    }
}
