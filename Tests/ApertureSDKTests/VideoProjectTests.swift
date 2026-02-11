import Testing
@testable import ApertureSDK

#if canImport(AVFoundation)
import AVFoundation

struct VideoProjectTests {
    
    @Test func projectInitialization() {
        let project = VideoProject(name: "Test Project")
        
        #expect(project.name == "Test Project")
        #expect(project.assets.isEmpty)
        #expect(project.resolution == CGSize(width: 1920, height: 1080))
        #expect(project.frameRate == 30)
    }
    
    @Test func projectCustomResolution() {
        let project = VideoProject(
            name: "4K Project",
            resolution: CGSize(width: 3840, height: 2160),
            frameRate: 60
        )
        
        #expect(project.resolution == CGSize(width: 3840, height: 2160))
        #expect(project.frameRate == 60)
    }
    
    @Test func timelineTracksInitialization() {
        let timeline = Timeline()
        
        #expect(timeline.tracks.isEmpty)
        #expect(timeline.currentTime == .zero)
        #expect(timeline.totalDuration == .zero)
    }
    
    @Test func addTrackToTimeline() {
        let timeline = Timeline()
        
        let videoTrack = timeline.addTrack(type: .video)
        #expect(timeline.tracks.count == 1)
        #expect(videoTrack.type == .video)
        
        let audioTrack = timeline.addTrack(type: .audio)
        #expect(timeline.tracks.count == 2)
        #expect(audioTrack.type == .audio)
    }
    
    @Test func removeTrackFromTimeline() {
        let timeline = Timeline()
        
        let track = timeline.addTrack(type: .video)
        #expect(timeline.tracks.count == 1)
        
        timeline.removeTrack(track)
        #expect(timeline.tracks.count == 0)
    }
    
    @Test func exportPresetResolutions() {
        #expect(ExportPreset.hd720p.resolution == CGSize(width: 1280, height: 720))
        #expect(ExportPreset.hd1080p.resolution == CGSize(width: 1920, height: 1080))
        #expect(ExportPreset.hd4K.resolution == CGSize(width: 3840, height: 2160))
        #expect(ExportPreset.instagram.resolution == CGSize(width: 1080, height: 1080))
        #expect(ExportPreset.twitter.resolution == CGSize(width: 1280, height: 720))
    }
    
    @Test func exportPresetBitrates() {
        #expect(ExportPreset.hd720p.bitrate == 5_000_000)
        #expect(ExportPreset.hd1080p.bitrate == 8_000_000)
        #expect(ExportPreset.hd4K.bitrate == 20_000_000)
    }
    
    @Test func customExportPreset() {
        let customPreset = ExportPreset.custom(width: 1920, height: 1080, bitrate: 10_000_000)
        #expect(customPreset.resolution == CGSize(width: 1920, height: 1080))
        #expect(customPreset.bitrate == 10_000_000)
    }
}

#endif
