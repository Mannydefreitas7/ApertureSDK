import Foundation
import Testing
@testable import VideoEditorCore

struct CaptionTests {
    
    @Test func captionInitialization() {
        let caption = Caption(startTime: 1.0, endTime: 3.5, text: "Hello World")
        
        #expect(caption.startTime == 1.0)
        #expect(caption.endTime == 3.5)
        #expect(caption.text == "Hello World")
        #expect(caption.duration == 2.5)
    }
    
    @Test func srtRoundTrip() {
        let srt = """
        1
        00:00:01,000 --> 00:00:03,500
        Hello World
        
        2
        00:00:05,000 --> 00:00:08,200
        Second caption
        """
        
        let track = CaptionTrack.fromSRT(srt)
        #expect(track.captions.count == 2)
        #expect(track.captions[0].text == "Hello World")
        #expect(track.captions[0].startTime == 1.0)
        #expect(track.captions[0].endTime == 3.5)
        #expect(track.captions[1].text == "Second caption")
        #expect(track.captions[1].startTime == 5.0)
        #expect(abs(track.captions[1].endTime - 8.2) <= 0.01)
        
        // Export back to SRT
        let exported = track.toSRT()
        #expect(exported.contains("Hello World"))
        #expect(exported.contains("Second caption"))
        #expect(exported.contains("00:00:01,000"))
        #expect(exported.contains("00:00:03,500"))
    }
    
    @Test func captionsAtTime() {
        let track = CaptionTrack(captions: [
            Caption(startTime: 1.0, endTime: 3.0, text: "First"),
            Caption(startTime: 2.5, endTime: 5.0, text: "Second"),
            Caption(startTime: 6.0, endTime: 8.0, text: "Third"),
        ])
        
        let atTime1 = track.captions(at: 1.5)
        #expect(atTime1.count == 1)
        #expect(atTime1[0].text == "First")
        
        // Overlapping captions
        let atTime2 = track.captions(at: 2.7)
        #expect(atTime2.count == 2)
        
        let atTime3 = track.captions(at: 10.0)
        #expect(atTime3.count == 0)
    }
    
    @Test func captionCodable() throws {
        let track = CaptionTrack(captions: [
            Caption(index: 1, startTime: 1.0, endTime: 3.0, text: "Test"),
        ])
        
        let data = try JSONEncoder().encode(track)
        let decoded = try JSONDecoder().decode(CaptionTrack.self, from: data)
        
        #expect(decoded.captions.count == 1)
        #expect(decoded.captions[0].text == "Test")
    }
}
