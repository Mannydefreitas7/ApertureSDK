import Testing
@testable import ApertureSDK

#if canImport(AVFoundation)
import AVFoundation

@available(iOS 15.0, macOS 12.0, *)
struct VideoMergerTests {
    
    @Test func mergerExists() {
        // Test that VideoMerger class exists and can be referenced
        #expect(VideoMerger.self != nil)
    }
}

#endif
