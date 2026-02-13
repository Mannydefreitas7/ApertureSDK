import Foundation
import Testing
@testable import VideoEditorCore

struct TimeRangeTests {
    
    @Test func timeRangeInit() {
        let range = ClipTimeRange(start: 5, duration: 10)
        #expect(range.start == 5)
        #expect(range.duration == 10)
        #expect(range.end == 15)
    }
    
    @Test func timeRangeContains() {
        let range = ClipTimeRange(start: 5, duration: 10)
        
        #expect(range.contains(5))
        #expect(range.contains(10))
        #expect(range.contains(14.9))
        #expect(!range.contains(4.9))
        #expect(!range.contains(15))
    }
    
    @Test func timeRangeOverlaps() {
        let range1 = ClipTimeRange(start: 0, duration: 10)
        let range2 = ClipTimeRange(start: 5, duration: 10)
        let range3 = ClipTimeRange(start: 10, duration: 5)
        let range4 = ClipTimeRange(start: 15, duration: 5)
        
        #expect(range1.overlaps(with: range2))
        #expect(!range1.overlaps(with: range3))
        #expect(!range1.overlaps(with: range4))
        #expect(range2.overlaps(with: range3))
    }
    
    @Test func timeRangeZero() {
        let zero = ClipTimeRange.zero
        #expect(zero.start == 0)
        #expect(zero.duration == 0)
        #expect(zero.end == 0)
    }
}

struct CanvasSizeTests {
    
    @Test func canvasSizePresets() {
        #expect(CanvasSize.hd720p.width == 1280)
        #expect(CanvasSize.hd720p.height == 720)
        #expect(CanvasSize.hd1080p.width == 1920)
        #expect(CanvasSize.hd1080p.height == 1080)
        #expect(CanvasSize.hd4K.width == 3840)
        #expect(CanvasSize.hd4K.height == 2160)
        #expect(CanvasSize.square1080.width == 1080)
        #expect(CanvasSize.square1080.height == 1080)
    }
    
    @Test func canvasSizeAspectRatio() {
        let widescreen = CanvasSize.hd1080p
        #expect(abs(widescreen.aspectRatio - 1920.0 / 1080.0) <= 0.001)
        
        let square = CanvasSize.square1080
        #expect(square.aspectRatio == 1.0)
    }
    
    @Test func canvasSizeCodable() throws {
        let size = CanvasSize(width: 1920, height: 1080)
        let data = try JSONEncoder().encode(size)
        let decoded = try JSONDecoder().decode(CanvasSize.self, from: data)
        
        #expect(decoded.width == 1920)
        #expect(decoded.height == 1080)
    }
}

struct ClipTransformTests {
    
    @Test func identityTransform() {
        let identity = ClipTransform.identity
        #expect(identity.positionX == 0.5)
        #expect(identity.positionY == 0.5)
        #expect(identity.scaleX == 1.0)
        #expect(identity.scaleY == 1.0)
        #expect(identity.rotation == 0)
    }
    
    @Test func transformCodable() throws {
        let transform = ClipTransform(positionX: 0.3, positionY: 0.7, scaleX: 2.0, scaleY: 1.5, rotation: 45)
        
        let data = try JSONEncoder().encode(transform)
        let decoded = try JSONDecoder().decode(ClipTransform.self, from: data)
        
        #expect(decoded.positionX == 0.3)
        #expect(decoded.positionY == 0.7)
        #expect(decoded.scaleX == 2.0)
        #expect(decoded.scaleY == 1.5)
        #expect(decoded.rotation == 45)
    }
}

struct ApertureErrorTests {
    
    @Test func errorDescriptions() {
        #expect(ApertureError.invalidConfiguration.localizedDescription == "Invalid configuration")
        #expect(ApertureError.invalidAsset.localizedDescription == "Invalid asset or cannot be loaded")
        #expect(ApertureError.unsupportedFormat.localizedDescription == "Unsupported format")
        #expect(ApertureError.insufficientPermissions.localizedDescription == "Insufficient permissions to access the resource")
        #expect(ApertureError.invalidTimeRange.localizedDescription == "Invalid time range specified")
        #expect(ApertureError.cancelled.localizedDescription == "Operation was cancelled")
    }
    
    @Test func errorEquality() {
        #expect(ApertureError.invalidAsset == ApertureError.invalidAsset)
        #expect(ApertureError.cancelled == ApertureError.cancelled)
        #expect(ApertureError.invalidAsset != ApertureError.cancelled)
    }
}
