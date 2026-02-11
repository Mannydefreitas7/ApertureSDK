import Testing
@testable import ApertureSDK

#if canImport(AVFoundation)
import AVFoundation

struct VideoTrimmerTests {
    
    @Test func trimmerExists() {
        // Test that VideoTrimmer class exists and can be referenced
        #expect(VideoTrimmer.self != nil)
    }
}

#endif
