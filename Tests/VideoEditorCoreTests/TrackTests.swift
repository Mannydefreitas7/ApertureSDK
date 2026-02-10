import XCTest
@testable import VideoEditorCore

final class TrackTests: XCTestCase {
    
    func testTrackInitialization() {
        let track = Track(type: .video)
        
        XCTAssertEqual(track.type, .video)
        XCTAssertTrue(track.clips.isEmpty)
        XCTAssertFalse(track.isMuted)
        XCTAssertFalse(track.isLocked)
        XCTAssertEqual(track.totalDuration, 0)
    }
    
    func testTrackAddClip() {
        var track = Track(type: .video)
        let clip = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        
        track.addClip(clip)
        XCTAssertEqual(track.clips.count, 1)
        XCTAssertEqual(track.totalDuration, 5)
    }
    
    func testTrackRemoveClip() {
        var track = Track(type: .video)
        let clip = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        track.addClip(clip)
        
        track.removeClip(id: clip.id)
        XCTAssertTrue(track.clips.isEmpty)
    }
    
    func testTrackMoveClip() {
        var track = Track(type: .video)
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        track.addClip(clip1)
        track.addClip(clip2)
        
        track.moveClip(from: 0, to: 1)
        XCTAssertEqual(track.clips[0].id, clip2.id)
        XCTAssertEqual(track.clips[1].id, clip1.id)
    }
    
    func testTrackClipAtTime() {
        var track = Track(type: .video)
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        track.addClip(clip1)
        track.addClip(clip2)
        
        let foundClip1 = track.clip(at: 2)
        XCTAssertEqual(foundClip1?.id, clip1.id)
        
        let foundClip2 = track.clip(at: 6)
        XCTAssertEqual(foundClip2?.id, clip2.id)
        
        let noClip = track.clip(at: 10)
        XCTAssertNil(noClip)
    }
    
    func testTrackTypes() {
        XCTAssertEqual(Track(type: .video).type, .video)
        XCTAssertEqual(Track(type: .audio).type, .audio)
        XCTAssertEqual(Track(type: .overlay).type, .overlay)
    }
}
