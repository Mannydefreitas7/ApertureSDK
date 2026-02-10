import XCTest
@testable import VideoEditorCore

final class ProjectTests: XCTestCase {
    
    func testProjectInitialization() {
        let project = Project(name: "Test Project")
        
        XCTAssertEqual(project.name, "Test Project")
        XCTAssertTrue(project.tracks.isEmpty)
        XCTAssertEqual(project.canvasSize, .hd1080p)
        XCTAssertEqual(project.fps, 30)
        XCTAssertEqual(project.audioSampleRate, 44100)
        XCTAssertEqual(project.totalDuration, 0)
    }
    
    func testProjectCustomCanvasSize() {
        let project = Project(
            name: "4K Project",
            canvasSize: .hd4K,
            fps: 60
        )
        
        XCTAssertEqual(project.canvasSize, .hd4K)
        XCTAssertEqual(project.fps, 60)
    }
    
    func testProjectAddTrack() {
        var project = Project(name: "Test")
        let track = Track(type: .video)
        
        project.addTrack(track)
        XCTAssertEqual(project.tracks.count, 1)
        XCTAssertEqual(project.tracks[0].type, .video)
    }
    
    func testProjectRemoveTrack() {
        var project = Project(name: "Test")
        let track = Track(type: .video)
        project.addTrack(track)
        XCTAssertEqual(project.tracks.count, 1)
        
        project.removeTrack(id: track.id)
        XCTAssertEqual(project.tracks.count, 0)
    }
    
    func testProjectTotalDuration() {
        var project = Project(name: "Test")
        var track = Track(type: .video)
        track.addClip(Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 5)))
        track.addClip(Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 3)))
        project.addTrack(track)
        
        XCTAssertEqual(project.totalDuration, 8)
    }
    
    func testProjectSerialization() throws {
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
        
        XCTAssertEqual(decoded.name, "Serialized Project")
        XCTAssertEqual(decoded.canvasSize, .hd720p)
        XCTAssertEqual(decoded.fps, 24)
        XCTAssertEqual(decoded.tracks.count, 1)
        XCTAssertEqual(decoded.tracks[0].clips.count, 1)
        XCTAssertEqual(decoded.tracks[0].clips[0].timeRange.duration, 10)
        XCTAssertEqual(decoded.tracks[0].clips[0].effects.count, 1)
        XCTAssertEqual(decoded.tracks[0].clips[0].effects[0].type, .brightness)
    }
}
