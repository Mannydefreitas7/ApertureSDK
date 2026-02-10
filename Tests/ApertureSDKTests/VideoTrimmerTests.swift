import XCTest
@testable import ApertureSDK

#if canImport(AVFoundation)
import AVFoundation

@available(iOS 15.0, macOS 12.0, *)
final class VideoTrimmerTests: XCTestCase {
    
    func testTrimmerExists() {
        // Test that VideoTrimmer class exists and can be referenced
        XCTAssertNotNil(VideoTrimmer.self)
    }
}

#endif
