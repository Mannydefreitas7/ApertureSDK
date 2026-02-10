import Foundation
import Testing
@testable import VideoEditorCore

struct CompoundClipTests {
    
    // MARK: - Clip.makeCompound
    
    @Test func makeCompoundFromClips() throws {
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        
        let compound = try #require(Clip.makeCompound(from: [clip1, clip2]))
        
        #expect(compound.type == .compound)
        #expect(compound.timeRange.duration == 8)
        #expect(compound.subTimeline?.count == 1)
        #expect(compound.subTimeline?[0].clips.count == 2)
        #expect(compound.subTimeline?[0].type == .video)
    }
    
    @Test func makeCompoundFromEmptyClipsReturnsNil() {
        let result = Clip.makeCompound(from: [])
        #expect(result == nil)
    }
    
    @Test func makeCompoundPreservesTrackType() throws {
        let clip = Clip(type: .audio, timeRange: ClipTimeRange(start: 0, duration: 4))
        
        let compound = try #require(Clip.makeCompound(from: [clip], trackType: .audio))
        #expect(compound.subTimeline?[0].type == .audio)
    }
    
    @Test func subTimelineDuration() {
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        let compound = Clip.makeCompound(from: [clip1, clip2])!
        
        #expect(compound.subTimelineDuration == 8)
    }
    
    @Test func subTimelineDurationWithoutSubTimeline() {
        let clip = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        #expect(clip.subTimelineDuration == 0)
    }
    
    // MARK: - Track.groupClips / ungroupCompoundClip
    
    @Test func trackGroupClips() throws {
        var track = Track(type: .video)
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        let clip3 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 2))
        track.addClip(clip1)
        track.addClip(clip2)
        track.addClip(clip3)
        
        let result = track.groupClips(ids: [clip1.id, clip2.id])
        let compound = try #require(result)
        
        // Track should now have 2 clips: compound + clip3
        #expect(track.clips.count == 2)
        #expect(track.clips[0].type == .compound)
        #expect(track.clips[0].id == compound.id)
        #expect(track.clips[1].id == clip3.id)
        
        // Duration should be preserved
        #expect(track.totalDuration == 10)
    }
    
    @Test func trackGroupClipsPreservesOrder() throws {
        var track = Track(type: .video)
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        let clip3 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 2))
        track.addClip(clip1)
        track.addClip(clip2)
        track.addClip(clip3)
        
        // Group clip2 and clip3 (not first)
        let result = track.groupClips(ids: [clip2.id, clip3.id])
        let compound = try #require(result)
        
        // Compound should be inserted at index 1 (where clip2 was)
        #expect(track.clips.count == 2)
        #expect(track.clips[0].id == clip1.id)
        #expect(track.clips[1].id == compound.id)
    }
    
    @Test func trackGroupSingleClipReturnsNil() {
        var track = Track(type: .video)
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        track.addClip(clip1)
        
        let result = track.groupClips(ids: [clip1.id])
        #expect(result == nil)
        #expect(track.clips.count == 1)
    }
    
    @Test func trackUngroupCompoundClip() throws {
        var track = Track(type: .video)
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        let clip3 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 2))
        track.addClip(clip1)
        track.addClip(clip2)
        track.addClip(clip3)
        
        let groupResult = track.groupClips(ids: [clip1.id, clip2.id])
        let compound = try #require(groupResult)
        #expect(track.clips.count == 2)
        
        let ungroupResult = track.ungroupCompoundClip(id: compound.id)
        let innerClips = try #require(ungroupResult)
        
        #expect(innerClips.count == 2)
        #expect(track.clips.count == 3)
        #expect(track.totalDuration == 10)
    }
    
    @Test func trackUngroupNonCompoundReturnsNil() {
        var track = Track(type: .video)
        let clip = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        track.addClip(clip)
        
        let result = track.ungroupCompoundClip(id: clip.id)
        #expect(result == nil)
        #expect(track.clips.count == 1)
    }
    
    // MARK: - Project-level grouping
    
    @Test func projectGroupClips() throws {
        var project = Project(name: "Test")
        var track = Track(type: .video)
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        track.addClip(clip1)
        track.addClip(clip2)
        project.addTrack(track)
        
        let compound = project.groupClips(ids: [clip1.id, clip2.id], inTrack: track.id)
        let unwrapped = try #require(compound)
        
        #expect(project.tracks[0].clips.count == 1)
        #expect(project.tracks[0].clips[0].id == unwrapped.id)
        #expect(project.totalDuration == 8)
    }
    
    @Test func projectUngroupCompoundClip() throws {
        var project = Project(name: "Test")
        var track = Track(type: .video)
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        track.addClip(clip1)
        track.addClip(clip2)
        project.addTrack(track)
        
        let groupResult = project.groupClips(ids: [clip1.id, clip2.id], inTrack: track.id)
        let compound = try #require(groupResult)
        
        let innerClips = project.ungroupCompoundClip(id: compound.id, inTrack: track.id)
        let unwrappedInner = try #require(innerClips)
        
        #expect(unwrappedInner.count == 2)
        #expect(project.tracks[0].clips.count == 2)
        #expect(project.totalDuration == 8)
    }
    
    @Test func projectGroupInvalidTrackReturnsNil() {
        var project = Project(name: "Test")
        let result = project.groupClips(ids: [UUID()], inTrack: UUID())
        #expect(result == nil)
    }
    
    // MARK: - Codable
    
    @Test func compoundClipCodable() throws {
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5),
                         sourceURL: URL(string: "file:///a.mp4"))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3),
                         sourceURL: URL(string: "file:///b.mp4"))
        let compound = try #require(Clip.makeCompound(from: [clip1, clip2]))
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(compound)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Clip.self, from: data)
        
        #expect(decoded.type == .compound)
        #expect(decoded.timeRange.duration == 8)
        #expect(decoded.subTimeline?.count == 1)
        #expect(decoded.subTimeline?[0].clips.count == 2)
        #expect(decoded.subTimeline?[0].clips[0].sourceURL?.absoluteString == "file:///a.mp4")
    }
    
    @Test func projectWithCompoundClipSerialization() throws {
        var project = Project(name: "Compound Test")
        var track = Track(type: .video)
        let clip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5))
        let clip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        track.addClip(clip1)
        track.addClip(clip2)
        project.addTrack(track)
        
        project.groupClips(ids: [clip1.id, clip2.id], inTrack: track.id)
        
        let json = try project.toJSON()
        let decoded = try Project.fromJSON(json)
        
        #expect(decoded.tracks[0].clips.count == 1)
        #expect(decoded.tracks[0].clips[0].type == .compound)
        #expect(decoded.tracks[0].clips[0].subTimeline?[0].clips.count == 2)
    }
    
    // MARK: - Nested compound clips
    
    @Test func nestedCompoundClip() throws {
        // Create an inner compound
        let innerClip1 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 2))
        let innerClip2 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3))
        let innerCompound = try #require(Clip.makeCompound(from: [innerClip1, innerClip2]))
        
        // Create an outer compound containing the inner one
        let clip3 = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 4))
        let outerCompound = try #require(Clip.makeCompound(from: [innerCompound, clip3]))
        
        #expect(outerCompound.type == .compound)
        #expect(outerCompound.timeRange.duration == 9) // 5 (inner) + 4
        #expect(outerCompound.subTimeline?[0].clips[0].type == .compound)
        #expect(outerCompound.subTimeline?[0].clips[0].subTimeline?[0].clips.count == 2)
    }
}
