# ApertureSDK

A powerful Swift Video Editor SDK for iOS and macOS, providing comprehensive video editing capabilities including trimming, merging, effects, overlays, and export functionality.

## Features

- 🎬 **Video Editing**: Trim, merge, and split video clips with ease
- 🎨 **Effects**: Apply filters like sepia, blur, brightness, contrast, and more
- 📝 **Overlays**: Add text and image overlays to your videos
- 🎵 **Audio**: Mix, replace, and process audio tracks
- 📤 **Export**: Export to multiple formats and resolutions (720p, 1080p, 4K)
- 🖼️ **SwiftUI Components**: Ready-to-use video player, timeline, and trimmer views
- 🔄 **Timeline Management**: Multi-track timeline with video, audio, and overlay tracks
- ⚡ **Performance**: Optimized for iOS and macOS with async/await support
- 📱 **Platform Support**: iOS 15.0+, macOS 12.0+
- 📦 **Swift Package Manager**: Easy integration

## Installation

### Swift Package Manager

Add ApertureSDK to your project using Swift Package Manager by adding it to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/Mannydefreitas7/ApertureSDK.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File > Add Packages...
2. Enter the repository URL: `https://github.com/Mannydefreitas7/ApertureSDK.git`
3. Select the version you want to use

## Quick Start

### Basic Video Project

```swift
import ApertureSDK
import AVFoundation

// Create a new video project
let project = VideoProject(name: "My Movie")

// Add video assets
let asset1 = try await VideoAsset(url: videoURL1)
let asset2 = try await VideoAsset(url: videoURL2)

project.addAsset(asset1)
project.addAsset(asset2)

// Export the project
try await project.export(
    to: outputURL,
    preset: .hd1080p,
    progress: { progress in
        print("Export progress: \(progress * 100)%")
    }
)
```

### Trimming Video

```swift
import ApertureSDK
import AVFoundation

// Load a video asset
let asset = try await VideoAsset(url: videoURL)

// Trim the video
try asset.trim(
    start: CMTime(seconds: 5, preferredTimescale: 600),
    end: CMTime(seconds: 15, preferredTimescale: 600)
)
```

### Applying Effects

```swift
import ApertureSDK

let asset = try await VideoAsset(url: videoURL)

// Apply a sepia filter
let sepiaEffect = FilterEffect.sepia(intensity: 0.8)
asset.applyEffect(sepiaEffect)

// Apply brightness adjustment
let brightnessEffect = FilterEffect.brightness(0.2)
asset.applyEffect(brightnessEffect)
```

### Adding Text Overlay

```swift
import ApertureSDK
import AVFoundation

let asset = try await VideoAsset(url: videoURL)

// Create a text overlay
let textOverlay = TextOverlay(
    text: "Hello World",
    font: .systemFont(ofSize: 48),
    color: .white,
    startTime: CMTime(seconds: 2, preferredTimescale: 600),
    duration: CMTime(seconds: 5, preferredTimescale: 600)
)

asset.addOverlay(textOverlay)
```

### Merging Videos

```swift
import ApertureSDK

// Merge multiple videos
try await VideoMerger.merge(
    urls: [videoURL1, videoURL2, videoURL3],
    outputURL: outputURL
)
```

### SwiftUI Integration

```swift
import SwiftUI
import ApertureSDK
import AVFoundation

struct ContentView: View {
    @State private var project = VideoProject(name: "My Project")
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
            }
            
            TimelineView(project: $project) { selectedAsset in
                self.asset = selectedAsset
            }
        }
    }
}
```

## Core Components

### VideoProject
Represents a video editing project with multiple assets, timeline management, and export capabilities.

### VideoAsset
Represents a video file with support for trimming, effects, and overlays.

### Timeline
Multi-track timeline system supporting video, audio, and overlay tracks.

### ExportManager
Handles video export with multiple preset configurations and progress reporting.

### Effects System
- **FilterEffect**: Apply visual filters (sepia, blur, brightness, contrast, saturation, etc.)
- **TransitionEffect**: Create transitions between clips (fade, crossfade, wipe, dissolve)

### Overlay System
- **TextOverlay**: Add animated text overlays
- **ImageOverlay**: Add image overlays with transformations

### Audio Features
- **AudioMixer**: Mix background music with video audio
- **AudioProcessor**: Extract, replace, and trim audio tracks

### SwiftUI Components
- **VideoPlayerView**: Full-featured video player with controls
- **TimelineView**: Visual timeline representation with drag-to-reorder
- **TrimmerView**: Interactive video trimmer with thumbnail preview

## Export Presets

ApertureSDK supports multiple export presets:

- `.hd720p` - 1280x720 resolution
- `.hd1080p` - 1920x1080 resolution (Full HD)
- `.hd4K` - 3840x2160 resolution (4K UHD)
- `.instagram` - 1080x1080 (Square format)
- `.twitter` - 1280x720 (Optimized for Twitter)
- `.custom(width:height:bitrate:)` - Custom resolution and bitrate

## Error Handling

ApertureSDK uses the `ApertureError` enum for error handling:

```swift
do {
    let asset = try await VideoAsset(url: videoURL)
} catch ApertureError.invalidAsset {
    print("Invalid video asset")
} catch ApertureError.exportFailed {
    print("Export failed")
} catch ApertureError.unsupportedFormat {
    print("Unsupported video format")
} catch ApertureError.insufficientPermissions {
    print("Insufficient permissions")
} catch ApertureError.invalidTimeRange {
    print("Invalid time range")
} catch {
    print("Unknown error: \(error)")
}
```

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 15.0+

## Building

To build the package:

```bash
swift build
```

To run tests:

```bash
swift test
```

## Architecture

ApertureSDK is built using native Apple frameworks:
- **AVFoundation** for video processing
- **CoreImage** for effects and filters
- **SwiftUI** for UI components
- **Combine** for reactive updates
- Modern **async/await** for concurrency

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.