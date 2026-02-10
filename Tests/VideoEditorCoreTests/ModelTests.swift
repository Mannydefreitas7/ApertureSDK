import XCTest
@testable import VideoEditorCore

final class TimeRangeTests: XCTestCase {
    
    func testTimeRangeInit() {
        let range = ClipTimeRange(start: 5, duration: 10)
        XCTAssertEqual(range.start, 5)
        XCTAssertEqual(range.duration, 10)
        XCTAssertEqual(range.end, 15)
    }
    
    func testTimeRangeContains() {
        let range = ClipTimeRange(start: 5, duration: 10)
        
        XCTAssertTrue(range.contains(5))
        XCTAssertTrue(range.contains(10))
        XCTAssertTrue(range.contains(14.9))
        XCTAssertFalse(range.contains(4.9))
        XCTAssertFalse(range.contains(15))
    }
    
    func testTimeRangeOverlaps() {
        let range1 = ClipTimeRange(start: 0, duration: 10)
        let range2 = ClipTimeRange(start: 5, duration: 10)
        let range3 = ClipTimeRange(start: 10, duration: 5)
        let range4 = ClipTimeRange(start: 15, duration: 5)
        
        XCTAssertTrue(range1.overlaps(with: range2))
        XCTAssertFalse(range1.overlaps(with: range3))
        XCTAssertFalse(range1.overlaps(with: range4))
        XCTAssertTrue(range2.overlaps(with: range3))
    }
    
    func testTimeRangeZero() {
        let zero = ClipTimeRange.zero
        XCTAssertEqual(zero.start, 0)
        XCTAssertEqual(zero.duration, 0)
        XCTAssertEqual(zero.end, 0)
    }
}

final class CanvasSizeTests: XCTestCase {
    
    func testCanvasSizePresets() {
        XCTAssertEqual(CanvasSize.hd720p.width, 1280)
        XCTAssertEqual(CanvasSize.hd720p.height, 720)
        XCTAssertEqual(CanvasSize.hd1080p.width, 1920)
        XCTAssertEqual(CanvasSize.hd1080p.height, 1080)
        XCTAssertEqual(CanvasSize.hd4K.width, 3840)
        XCTAssertEqual(CanvasSize.hd4K.height, 2160)
        XCTAssertEqual(CanvasSize.square1080.width, 1080)
        XCTAssertEqual(CanvasSize.square1080.height, 1080)
    }
    
    func testCanvasSizeAspectRatio() {
        let widescreen = CanvasSize.hd1080p
        XCTAssertEqual(widescreen.aspectRatio, 1920.0 / 1080.0, accuracy: 0.001)
        
        let square = CanvasSize.square1080
        XCTAssertEqual(square.aspectRatio, 1.0)
    }
    
    func testCanvasSizeCodable() throws {
        let size = CanvasSize(width: 1920, height: 1080)
        let data = try JSONEncoder().encode(size)
        let decoded = try JSONDecoder().decode(CanvasSize.self, from: data)
        
        XCTAssertEqual(decoded.width, 1920)
        XCTAssertEqual(decoded.height, 1080)
    }
}

final class ClipTransformTests: XCTestCase {
    
    func testIdentityTransform() {
        let identity = ClipTransform.identity
        XCTAssertEqual(identity.positionX, 0.5)
        XCTAssertEqual(identity.positionY, 0.5)
        XCTAssertEqual(identity.scaleX, 1.0)
        XCTAssertEqual(identity.scaleY, 1.0)
        XCTAssertEqual(identity.rotation, 0)
    }
    
    func testTransformCodable() throws {
        let transform = ClipTransform(positionX: 0.3, positionY: 0.7, scaleX: 2.0, scaleY: 1.5, rotation: 45)
        
        let data = try JSONEncoder().encode(transform)
        let decoded = try JSONDecoder().decode(ClipTransform.self, from: data)
        
        XCTAssertEqual(decoded.positionX, 0.3)
        XCTAssertEqual(decoded.positionY, 0.7)
        XCTAssertEqual(decoded.scaleX, 2.0)
        XCTAssertEqual(decoded.scaleY, 1.5)
        XCTAssertEqual(decoded.rotation, 45)
    }
}

final class VideoEditorErrorTests: XCTestCase {
    
    func testErrorDescriptions() {
        XCTAssertEqual(VideoEditorError.invalidConfiguration.localizedDescription, "Invalid configuration")
        XCTAssertEqual(VideoEditorError.invalidAsset.localizedDescription, "Invalid asset or cannot be loaded")
        XCTAssertEqual(VideoEditorError.unsupportedFormat.localizedDescription, "Unsupported format")
        XCTAssertEqual(VideoEditorError.insufficientPermissions.localizedDescription, "Insufficient permissions to access the resource")
        XCTAssertEqual(VideoEditorError.invalidTimeRange.localizedDescription, "Invalid time range specified")
        XCTAssertEqual(VideoEditorError.cancelled.localizedDescription, "Operation was cancelled")
    }
    
    func testErrorEquality() {
        XCTAssertEqual(VideoEditorError.invalidAsset, VideoEditorError.invalidAsset)
        XCTAssertEqual(VideoEditorError.cancelled, VideoEditorError.cancelled)
        XCTAssertNotEqual(VideoEditorError.invalidAsset, VideoEditorError.cancelled)
    }
}
