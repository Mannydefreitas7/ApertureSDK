import Testing
@testable import VideoEditorCore

struct TrackTests {
    
    @Test func trackInitialization() {
        let track = Track(type: .video)
        
        #expect(track.type == .video)
        #expect(track.clips.isEmpty)
        #expect(!track.isMuted)
        #expect(!track.isLocked)
        #expect(track.totalDuration == 0)
    }
    
    @Test func trackAddClip() {
        var track = Track(type: .video)
        let clip = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        
        track.addClip(clip)
        #expect(track.clips.count == 1)
        #expect(track.totalDuration == 5)
    }
    
    @Test func trackRemoveClip() {
        var track = Track(type: .video)
        let clip = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        track.addClip(clip)
        
        track.removeClip(id: clip.id)
        #expect(track.clips.isEmpty)
    }
    
    @Test func trackMoveClip() {
        var track = Track(type: .video)
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        track.addClip(clip1)
        track.addClip(clip2)
        
        track.moveClip(from: 0, to: 1)
        #expect(track.clips[0].id == clip2.id)
        #expect(track.clips[1].id == clip1.id)
    }
    
    @Test func trackClipAtTime() {
        var track = Track(type: .video)
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        track.addClip(clip1)
        track.addClip(clip2)
        
        let foundClip1 = track.clip(at: 2)
        #expect(foundClip1?.id == clip1.id)
        
        let foundClip2 = track.clip(at: 6)
        #expect(foundClip2?.id == clip2.id)
        
        let noClip = track.clip(at: 10)
        #expect(noClip == nil)
    }
    
    @Test func trackTypes() {
        #expect(Track(type: .video).type == .video)
        #expect(Track(type: .audio).type == .audio)
        #expect(Track(type: .overlay).type == .overlay)
    }
}
