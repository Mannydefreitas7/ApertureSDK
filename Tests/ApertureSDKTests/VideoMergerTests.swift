import XCTest
@testable import ApertureSDK

#if canImport(AVFoundation)
import AVFoundation

@available(iOS 15.0, macOS 12.0, *)
final class VideoMergerTests: XCTestCase {
    
    func testMergerExists() {
        // Test that VideoMerger class exists and can be referenced
        XCTAssertNotNil(VideoMerger.self)
    }
}

#endif
