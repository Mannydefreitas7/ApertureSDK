import Foundation
import Testing
@testable import VideoEditorCore

struct ProjectTests {
    
    @Test func projectInitialization() {
        let project = Project(name: "Test Project")
        
        #expect(project.name == "Test Project")
        #expect(project.tracks.isEmpty)
        #expect(project.canvasSize == .hd1080p)
        #expect(project.fps == 30)
        #expect(project.audioSampleRate == 44100)
        #expect(project.totalDuration == 0)
    }
    
    @Test func projectCustomCanvasSize() {
        let project = Project(
            name: "4K Project",
            canvasSize: .hd4K,
            fps: 60
        )
        
        #expect(project.canvasSize == .hd4K)
        #expect(project.fps == 60)
    }
    
    @Test func projectAddTrack() {
        var project = Project(name: "Test")
        let track = Track(type: .video)
        
        project.addTrack(track)
        #expect(project.tracks.count == 1)
        #expect(project.tracks[0].type == .video)
    }
    
    @Test func projectRemoveTrack() {
        var project = Project(name: "Test")
        let track = Track(type: .video)
        project.addTrack(track)
        #expect(project.tracks.count == 1)
        
        project.removeTrack(id: track.id)
        #expect(project.tracks.count == 0)
    }
    
    @Test func projectTotalDuration() {
        var project = Project(name: "Test")
        var track = Track(type: .video)
        track.addClip(Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5)))
        track.addClip(Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3)))
        project.addTrack(track)
        
        #expect(project.totalDuration == 8)
    }
    
    @Test func projectSerialization() throws {
        var project = Project(name: "Serialized Project", canvasSize: .hd720p, fps: 24)
        var track = Track(type: .video)
        let clip = Clip(
            type: .video,
            timeRange: ClipTimeRange(start: 0, duration: 10),
            sourceURL: URL(string: "file:///test.mp4"),
            effects: [.brightness(0.5)]
        )
        track.addClip(clip)
        project.addTrack(track)
        
        let json = try project.toJSON()
        let decoded = try Project.fromJSON(json)
        
        #expect(decoded.name == "Serialized Project")
        #expect(decoded.canvasSize == .hd720p)
        #expect(decoded.fps == 24)
        #expect(decoded.tracks.count == 1)
        #expect(decoded.tracks[0].clips.count == 1)
        #expect(decoded.tracks[0].clips[0].timeRange.duration == 10)
        #expect(decoded.tracks[0].clips[0].effects.count == 1)
        #expect(decoded.tracks[0].clips[0].effects[0].type == .brightness)
    }
}
