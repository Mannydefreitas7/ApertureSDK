import XCTest
@testable import ApertureSDK

#if canImport(AVFoundation)
import AVFoundation

@available(iOS 15.0, macOS 12.0, *)
final class VideoProjectTests: XCTestCase {
    
    func testProjectInitialization() {
        let project = VideoProject(name: "Test Project")
        
        XCTAssertEqual(project.name, "Test Project")
        XCTAssertTrue(project.assets.isEmpty)
        XCTAssertEqual(project.resolution, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(project.frameRate, 30)
    }
    
    func testProjectCustomResolution() {
        let project = VideoProject(
            name: "4K Project",
            resolution: CGSize(width: 3840, height: 2160),
            frameRate: 60
        )
        
        XCTAssertEqual(project.resolution, CGSize(width: 3840, height: 2160))
        XCTAssertEqual(project.frameRate, 60)
    }
    
    func testTimelineTracksInitialization() {
        let timeline = Timeline()
        
        XCTAssertTrue(timeline.tracks.isEmpty)
        XCTAssertEqual(timeline.currentTime, .zero)
        XCTAssertEqual(timeline.totalDuration, .zero)
    }
    
    func testAddTrackToTimeline() {
        let timeline = Timeline()
        
        let videoTrack = timeline.addTrack(type: .video)
        XCTAssertEqual(timeline.tracks.count, 1)
        XCTAssertEqual(videoTrack.type, .video)
        
        let audioTrack = timeline.addTrack(type: .audio)
        XCTAssertEqual(timeline.tracks.count, 2)
        XCTAssertEqual(audioTrack.type, .audio)
    }
    
    func testRemoveTrackFromTimeline() {
        let timeline = Timeline()
        
        let track = timeline.addTrack(type: .video)
        XCTAssertEqual(timeline.tracks.count, 1)
        
        timeline.removeTrack(track)
        XCTAssertEqual(timeline.tracks.count, 0)
    }
    
    func testExportPresetResolutions() {
        XCTAssertEqual(ExportPreset.hd720p.resolution, CGSize(width: 1280, height: 720))
        XCTAssertEqual(ExportPreset.hd1080p.resolution, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(ExportPreset.hd4K.resolution, CGSize(width: 3840, height: 2160))
        XCTAssertEqual(ExportPreset.instagram.resolution, CGSize(width: 1080, height: 1080))
        XCTAssertEqual(ExportPreset.twitter.resolution, CGSize(width: 1280, height: 720))
    }
    
    func testExportPresetBitrates() {
        XCTAssertEqual(ExportPreset.hd720p.bitrate, 5_000_000)
        XCTAssertEqual(ExportPreset.hd1080p.bitrate, 8_000_000)
        XCTAssertEqual(ExportPreset.hd4K.bitrate, 20_000_000)
    }
    
    func testCustomExportPreset() {
        let customPreset = ExportPreset.custom(width: 1920, height: 1080, bitrate: 10_000_000)
        XCTAssertEqual(customPreset.resolution, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(customPreset.bitrate, 10_000_000)
    }
}

#endif
