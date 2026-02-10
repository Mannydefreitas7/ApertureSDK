import XCTest
@testable import VideoEditorCore

final class CaptionTests: XCTestCase {
    
    func testCaptionInitialization() {
        let caption = Caption(startTime: 1.0, endTime: 3.5, text: "Hello World")
        
        XCTAssertEqual(caption.startTime, 1.0)
        XCTAssertEqual(caption.endTime, 3.5)
        XCTAssertEqual(caption.text, "Hello World")
        XCTAssertEqual(caption.duration, 2.5)
    }
    
    func testSRTRoundTrip() {
        let srt = """
        1
        00:00:01,000 --> 00:00:03,500
        Hello World
        
        2
        00:00:05,000 --> 00:00:08,200
        Second caption
        """
        
        let track = CaptionTrack.fromSRT(srt)
        XCTAssertEqual(track.captions.count, 2)
        XCTAssertEqual(track.captions[0].text, "Hello World")
        XCTAssertEqual(track.captions[0].startTime, 1.0)
        XCTAssertEqual(track.captions[0].endTime, 3.5)
        XCTAssertEqual(track.captions[1].text, "Second caption")
        XCTAssertEqual(track.captions[1].startTime, 5.0)
        XCTAssertEqual(track.captions[1].endTime, 8.2, accuracy: 0.01)
        
        // Export back to SRT
        let exported = track.toSRT()
        XCTAssertTrue(exported.contains("Hello World"))
        XCTAssertTrue(exported.contains("Second caption"))
        XCTAssertTrue(exported.contains("00:00:01,000"))
        XCTAssertTrue(exported.contains("00:00:03,500"))
    }
    
    func testCaptionsAtTime() {
        let track = CaptionTrack(captions: [
            Caption(startTime: 1.0, endTime: 3.0, text: "First"),
            Caption(startTime: 2.5, endTime: 5.0, text: "Second"),
            Caption(startTime: 6.0, endTime: 8.0, text: "Third"),
        ])
        
        let atTime1 = track.captions(at: 1.5)
        XCTAssertEqual(atTime1.count, 1)
        XCTAssertEqual(atTime1[0].text, "First")
        
        // Overlapping captions
        let atTime2 = track.captions(at: 2.7)
        XCTAssertEqual(atTime2.count, 2)
        
        let atTime3 = track.captions(at: 10.0)
        XCTAssertEqual(atTime3.count, 0)
    }
    
    func testCaptionCodable() throws {
        let track = CaptionTrack(captions: [
            Caption(index: 1, startTime: 1.0, endTime: 3.0, text: "Test"),
        ])
        
        let data = try JSONEncoder().encode(track)
        let decoded = try JSONDecoder().decode(CaptionTrack.self, from: data)
        
        XCTAssertEqual(decoded.captions.count, 1)
        XCTAssertEqual(decoded.captions[0].text, "Test")
    }
}
