import Testing
@testable import ApertureSDK

#if canImport(AVFoundation)
import AVFoundation

@available(iOS 15.0, macOS 12.0, *)
struct VideoTrimmerTests {
    
    @Test func trimmerExists() {
        // Test that VideoTrimmer class exists and can be referenced
        #expect(VideoTrimmer.self != nil)
    }
}

#endif
