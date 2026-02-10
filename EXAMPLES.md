# ApertureSDK Examples

This document contains comprehensive usage examples for ApertureSDK.

## Table of Contents

1. [Basic Video Editing](#basic-video-editing)
2. [Trimming Videos](#trimming-videos)
3. [Merging Videos](#merging-videos)
4. [Splitting Videos](#splitting-videos)
5. [Applying Effects](#applying-effects)
6. [Adding Overlays](#adding-overlays)
7. [Audio Processing](#audio-processing)
8. [Export Configuration](#export-configuration)
9. [SwiftUI Integration](#swiftui-integration)

## Basic Video Editing

### Creating a Simple Video Project

```swift
import ApertureSDK
import AVFoundation

// Create a new video project
let project = VideoProject(name: "My First Project")

// Load video assets
let asset1 = try await VideoAsset(url: URL(fileURLWithPath: "/path/to/video1.mp4"))
let asset2 = try await VideoAsset(url: URL(fileURLWithPath: "/path/to/video2.mp4"))

// Add assets to the project
project.addAsset(asset1)
project.addAsset(asset2)

// Export the project
try await project.export(
    to: URL(fileURLWithPath: "/path/to/output.mp4"),
    preset: .hd1080p,
    progress: { progress in
        print("Export progress: \(Int(progress * 100))%")
    }
)

print("Video project exported successfully!")
```

### Creating a Custom Resolution Project

```swift
// Create a 4K project at 60 fps
let project = VideoProject(
    name: "4K Project",
    resolution: CGSize(width: 3840, height: 2160),
    frameRate: 60
)
```

## Trimming Videos

### Trim a Single Video

```swift
import ApertureSDK
import AVFoundation

// Load a video asset
let asset = try await VideoAsset(url: videoURL)

// Trim to keep seconds 5 through 15
try asset.trim(
    start: CMTime(seconds: 5, preferredTimescale: 600),
    end: CMTime(seconds: 15, preferredTimescale: 600)
)

// Create a project and export
let project = VideoProject(name: "Trimmed Video")
project.addAsset(asset)
try await project.export(to: outputURL, preset: .hd1080p)
```

### Trim and Export Directly

```swift
try await VideoTrimmer.trimAndExport(
    inputURL: URL(fileURLWithPath: "/path/to/input.mp4"),
    outputURL: URL(fileURLWithPath: "/path/to/output.mp4"),
    startTime: CMTime(seconds: 10, preferredTimescale: 600),
    endTime: CMTime(seconds: 30, preferredTimescale: 600)
)
```

## Merging Videos

### Merge Multiple Videos

```swift
import ApertureSDK

let videoURLs = [
    URL(fileURLWithPath: "/path/to/video1.mp4"),
    URL(fileURLWithPath: "/path/to/video2.mp4"),
    URL(fileURLWithPath: "/path/to/video3.mp4")
]

try await VideoMerger.merge(
    urls: videoURLs,
    outputURL: URL(fileURLWithPath: "/path/to/merged.mp4")
)
```

### Merge with Custom Resolution

```swift
let assets = [asset1, asset2, asset3]

try await VideoMerger.merge(
    assets: assets,
    outputURL: outputURL,
    resolution: CGSize(width: 1920, height: 1080)
)
```

## Splitting Videos

### Split at Specific Time Points

```swift
import ApertureSDK
import AVFoundation

let splitPoints = [
    CMTime(seconds: 10, preferredTimescale: 600),
    CMTime(seconds: 20, preferredTimescale: 600),
    CMTime(seconds: 30, preferredTimescale: 600)
]

let outputURLs = try await VideoSplitter.split(
    inputURL: URL(fileURLWithPath: "/path/to/video.mp4"),
    at: splitPoints,
    outputDirectory: URL(fileURLWithPath: "/path/to/output/"),
    baseFileName: "clip"
)

// Results in: clip_1.mp4, clip_2.mp4, clip_3.mp4, clip_4.mp4
print("Created \(outputURLs.count) segments")
```

### Split into Equal Segments

```swift
let outputURLs = try await VideoSplitter.splitIntoSegments(
    inputURL: videoURL,
    segmentCount: 4,
    outputDirectory: outputDirectory,
    baseFileName: "segment"
)
```

## Applying Effects

### Basic Filters

```swift
import ApertureSDK

let asset = try await VideoAsset(url: videoURL)

// Sepia filter
let sepiaEffect = FilterEffect.sepia(intensity: 0.8)
asset.applyEffect(sepiaEffect)

// Black and white
let bwEffect = FilterEffect.blackAndWhite()
asset.applyEffect(bwEffect)

// Brightness
let brightnessEffect = FilterEffect.brightness(0.3)
asset.applyEffect(brightnessEffect)

// Contrast
let contrastEffect = FilterEffect.contrast(1.5)
asset.applyEffect(contrastEffect)

// Saturation
let saturationEffect = FilterEffect.saturation(1.3)
asset.applyEffect(saturationEffect)

// Blur
let blurEffect = FilterEffect.blur(radius: 5.0)
asset.applyEffect(blurEffect)

// Sharpen
let sharpenEffect = FilterEffect.sharpen(intensity: 2.0)
asset.applyEffect(sharpenEffect)
```

### Transition Effects

```swift
import ApertureSDK
import AVFoundation

// Fade in transition
let fadeIn = TransitionEffect.fadeIn(
    duration: CMTime(seconds: 1, preferredTimescale: 600)
)

// Crossfade transition
let crossfade = TransitionEffect.crossfade(
    duration: CMTime(seconds: 2, preferredTimescale: 600)
)

// Wipe transitions
let wipeLeft = TransitionEffect(
    type: .wipeLeft,
    duration: CMTime(seconds: 1.5, preferredTimescale: 600)
)
```

## Adding Overlays

### Text Overlay with Animation

```swift
import ApertureSDK
import AVFoundation

let asset = try await VideoAsset(url: videoURL)

// Simple text overlay
let textOverlay = TextOverlay(
    text: "Hello World!",
    font: .boldSystemFont(ofSize: 48),
    color: .white,
    startTime: CMTime(seconds: 2, preferredTimescale: 600),
    duration: CMTime(seconds: 5, preferredTimescale: 600),
    position: CGPoint(x: 0.5, y: 0.9) // Bottom center
)

// Add animation
textOverlay.animation = .fadeInOut
textOverlay.backgroundColor = .black.withAlphaComponent(0.5)
textOverlay.alignment = .center

asset.addOverlay(textOverlay)
```

### Image Overlay

```swift
import ApertureSDK
import CoreImage
import AVFoundation

let asset = try await VideoAsset(url: videoURL)

// Load an image
guard let image = CIImage(contentsOf: logoURL) else { return }

// Create image overlay
let imageOverlay = ImageOverlay(
    image: image,
    startTime: CMTime(seconds: 0, preferredTimescale: 600),
    duration: CMTime(seconds: 10, preferredTimescale: 600),
    position: CGPoint(x: 0.1, y: 0.1), // Top left
    scale: 0.3
)

// Add fade in animation
imageOverlay.animation = .fadeIn

// Add rotation
imageOverlay.rotation = .pi / 8 // 22.5 degrees

asset.addOverlay(imageOverlay)
```

## Audio Processing

### Mix Background Music

```swift
import ApertureSDK

try await AudioMixer.mixAudio(
    videoURL: URL(fileURLWithPath: "/path/to/video.mp4"),
    backgroundMusicURL: URL(fileURLWithPath: "/path/to/music.mp3"),
    outputURL: URL(fileURLWithPath: "/path/to/output.mp4"),
    videoVolume: 0.7,
    musicVolume: 0.3
)
```

### Extract Audio from Video

```swift
try await AudioProcessor.extractAudio(
    from: URL(fileURLWithPath: "/path/to/video.mp4"),
    outputURL: URL(fileURLWithPath: "/path/to/audio.m4a"),
    format: .m4a
)
```

### Replace Audio Track

```swift
try await AudioProcessor.replaceAudio(
    in: URL(fileURLWithPath: "/path/to/video.mp4"),
    with: URL(fileURLWithPath: "/path/to/new-audio.mp3"),
    outputURL: URL(fileURLWithPath: "/path/to/output.mp4")
)
```

### Adjust Volume

```swift
try await AudioMixer.adjustVolume(
    inputURL: videoURL,
    outputURL: outputURL,
    volume: 0.5 // 50% volume
)
```

## Export Configuration

### Using Different Presets

```swift
// 720p HD
try await project.export(to: outputURL, preset: .hd720p)

// 1080p Full HD
try await project.export(to: outputURL, preset: .hd1080p)

// 4K UHD
try await project.export(to: outputURL, preset: .hd4K)

// Instagram square format
try await project.export(to: outputURL, preset: .instagram)

// Twitter optimized
try await project.export(to: outputURL, preset: .twitter)

// Custom preset
let customPreset = ExportPreset.custom(
    width: 1920,
    height: 1080,
    bitrate: 10_000_000
)
try await project.export(to: outputURL, preset: customPreset)
```

### Export with Progress Tracking

```swift
try await project.export(
    to: outputURL,
    preset: .hd1080p,
    progress: { progress in
        DispatchQueue.main.async {
            // Update UI with progress
            progressView.progress = Float(progress)
            percentLabel.text = "\(Int(progress * 100))%"
        }
    }
)
```

## SwiftUI Integration

### Complete Video Editor View

```swift
import SwiftUI
import ApertureSDK
import AVFoundation

struct VideoEditorView: View {
    @State private var project = VideoProject(name: "My Project")
    @State private var selectedAsset: VideoAsset?
    @State private var currentTime: CMTime = .zero
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    
    var body: some View {
        VStack {
            // Video Player
            if let asset = selectedAsset {
                VideoPlayerView(
                    asset: .constant(asset),
                    currentTime: $currentTime,
                    showControls: true
                )
                .frame(height: 300)
                
                // Trimmer
                TrimmerView(asset: .constant(asset)) { start, end in
                    try? asset.trim(start: start, end: end)
                }
                .frame(height: 120)
            }
            
            // Timeline
            TimelineView(project: $project) { asset in
                selectedAsset = asset
            }
            .frame(height: 200)
            
            // Controls
            HStack {
                Button("Add Video") {
                    // Show file picker
                }
                
                Button("Export") {
                    exportVideo()
                }
                .disabled(isExporting)
                
                if isExporting {
                    ProgressView(value: exportProgress)
                        .frame(width: 100)
                }
            }
            .padding()
        }
    }
    
    private func exportVideo() {
        isExporting = true
        
        Task {
            do {
                try await project.export(
                    to: getOutputURL(),
                    preset: .hd1080p,
                    progress: { progress in
                        exportProgress = progress
                    }
                )
                isExporting = false
                // Show success message
            } catch {
                isExporting = false
                // Show error message
            }
        }
    }
    
    private func getOutputURL() -> URL {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        return documentsPath.appendingPathComponent("export.mp4")
    }
}
```

### Simple Video Player

```swift
import SwiftUI
import ApertureSDK
import AVFoundation

struct SimplePlayerView: View {
    let videoURL: URL
    @State private var asset: VideoAsset?
    @State private var currentTime: CMTime = .zero
    
    var body: some View {
        VStack {
            if let asset = asset {
                VideoPlayerView(
                    asset: .constant(asset),
                    currentTime: $currentTime,
                    showControls: true
                )
            } else {
                ProgressView("Loading video...")
            }
        }
        .task {
            do {
                asset = try await VideoAsset(url: videoURL)
            } catch {
                print("Failed to load video: \(error)")
            }
        }
    }
}
```

## Error Handling Example

```swift
import ApertureSDK

func processVideo() async {
    do {
        let asset = try await VideoAsset(url: videoURL)
        try asset.trim(start: .zero, end: CMTime(seconds: 10, preferredTimescale: 600))
        
        let project = VideoProject(name: "Test")
        project.addAsset(asset)
        
        try await project.export(to: outputURL, preset: .hd1080p)
        
        print("Success!")
        
    } catch ApertureError.invalidAsset {
        print("The video file is invalid or cannot be loaded")
    } catch ApertureError.exportFailed {
        print("Export operation failed")
    } catch ApertureError.unsupportedFormat {
        print("This video format is not supported")
    } catch ApertureError.insufficientPermissions {
        print("App doesn't have permission to access this file")
    } catch ApertureError.invalidTimeRange {
        print("The specified time range is invalid")
    } catch {
        print("An unexpected error occurred: \(error)")
    }
}
```

## Advanced Example: Complete Video Editor

```swift
import ApertureSDK
import AVFoundation

func createCompleteVideo() async throws {
    // Create project
    let project = VideoProject(name: "My Movie", resolution: CGSize(width: 1920, height: 1080))
    
    // Load and trim first clip
    let clip1 = try await VideoAsset(url: video1URL)
    try clip1.trim(
        start: CMTime(seconds: 5, preferredTimescale: 600),
        end: CMTime(seconds: 20, preferredTimescale: 600)
    )
    
    // Apply effects to first clip
    clip1.applyEffect(FilterEffect.brightness(0.2))
    clip1.applyEffect(FilterEffect.saturation(1.3))
    
    // Add text overlay
    let titleOverlay = TextOverlay(
        text: "My Amazing Video",
        font: .boldSystemFont(ofSize: 64),
        color: .white,
        startTime: CMTime(seconds: 0, preferredTimescale: 600),
        duration: CMTime(seconds: 3, preferredTimescale: 600),
        position: CGPoint(x: 0.5, y: 0.5)
    )
    titleOverlay.animation = .fadeInOut
    clip1.addOverlay(titleOverlay)
    
    // Load second clip
    let clip2 = try await VideoAsset(url: video2URL)
    clip2.applyEffect(FilterEffect.sepia(intensity: 0.7))
    
    // Add clips to project
    project.addAsset(clip1)
    project.addAsset(clip2)
    
    // Export with progress tracking
    try await project.export(
        to: outputURL,
        preset: .hd1080p,
        progress: { progress in
            print("Exporting: \(Int(progress * 100))%")
        }
    )
    
    print("Video creation complete!")
}
```
