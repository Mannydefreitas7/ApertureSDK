import Testing
@testable import ApertureSDK

#if canImport(AVFoundation)
import AVFoundation

struct VideoMergerTests {
    
    @Test func mergerExists() {
        // Test that VideoMerger class exists and can be referenced
        #expect(VideoMerger.self != nil)
    }
}

#endif
