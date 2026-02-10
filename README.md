# ApertureSDK

A powerful Swift Video Editor SDK for iOS and macOS, providing comprehensive video editing capabilities including trimming, merging, effects, overlays, and export functionality.

## Features

- 🎬 **Core Editing**: Multi-track timeline (video + audio + overlays), trim/split, drag reorder, crop/rotate/transform
- 🎨 **Effects**: Filters (sepia, B&W, brightness, contrast, saturation, blur, sharpen, vignette), LUT support
- 🔀 **Transitions**: Cross dissolve, slide, wipe, fade
- 📝 **Overlays**: Timed text overlays, image/sticker overlays, picture-in-picture
- 📄 **Captions**: SRT subtitle import/export
- 🎵 **Audio**: Volume control, fade in/out, mute, audio extraction
- 📤 **Export**: H.264/H.265, target bitrate, fps, resolution presets, progress + cancel, watermark hook
- 🖼️ **SwiftUI Components**: VideoEditorView, PreviewView, ProjectTimelineView, ClipInspectorView, ExportButton
- 🔄 **Timeline-first Data Model**: Serializable Codable models independent of AVFoundation
- ⚡ **Modern Swift**: async/await, Sendable types, structured concurrency
- 📱 **Platform Support**: iOS 15.0+, macOS 12.0+
- 📦 **Modular SwiftPM**: Use the full SDK or just the parts you need

## Package Layout (SwiftPM)

ApertureSDK is split into focused modules so you can use only what you need:

| Package | Description | Dependencies |
|---------|-------------|--------------|
| **VideoEditorCore** | Pure Swift models + timeline logic (Codable, no AVFoundation) | Foundation only |
| **VideoEditorEngine** | AVFoundation + CoreImage render pipeline | VideoEditorCore |
| **VideoEditorExport** | Export session, presets, progress + cancel | VideoEditorCore, VideoEditorEngine |
| **VideoEditorSwiftUI** | SwiftUI components + bindings | VideoEditorCore, VideoEditorEngine, VideoEditorExport |
| **VideoEditorAssets** | LUT loader, bundled resources | VideoEditorCore |
| **ApertureSDK** | Umbrella module that re-exports everything | All of the above |

This lets you:
- **Use the engine with UIKit or SwiftUI** — import `VideoEditorCore` + `VideoEditorEngine`
- **Embed the ready-made SwiftUI editor** — import `VideoEditorSwiftUI`
- **Build your own UI on top of Core + Engine** — skip the SwiftUI module entirely
- **Use just the data models** — import only `VideoEditorCore` for serialization/deserialization

## Installation

### Swift Package Manager

Add ApertureSDK to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/Mannydefreitas7/ApertureSDK.git", from: "1.0.0")
]
```

Then choose which modules to import:

```swift
// Import everything
.target(name: "MyApp", dependencies: [
    .product(name: "ApertureSDK", package: "ApertureSDK")
])

// Or pick individual modules
.target(name: "MyApp", dependencies: [
    .product(name: "VideoEditorCore", package: "ApertureSDK"),
    .product(name: "VideoEditorEngine", package: "ApertureSDK"),
])
```

Or add it directly in Xcode:
1. File > Add Packages...
2. Enter the repository URL: `https://github.com/Mannydefreitas7/ApertureSDK.git`
3. Select the version you want to use

## Quick Start

### Creating a Project (VideoEditorCore)

The timeline data model is pure Swift, Codable, and independent of AVFoundation:

```swift
import VideoEditorCore

// Create a project
var project = Project(name: "My Movie", canvasSize: .hd1080p, fps: 30)

// Add tracks and clips
var videoTrack = Track(type: .video)
videoTrack.addClip(Clip(
    type: .video,
    timeRange: ClipTimeRange(start: 0, duration: 10),
    sourceURL: videoURL
))
project.addTrack(videoTrack)

// Add effects
var clip = project.tracks[0].clips[0]
clip.effects.append(.brightness(0.2))
clip.effects.append(.contrast(1.1))

// Serialize to JSON for save/load
let json = try project.toJSON()
let loaded = try Project.fromJSON(json)
```

### Split and Trim Clips

```swift
import VideoEditorCore

var clip = Clip(type: .video, timeRange: ClipTimeRange(start: 0, duration: 10))

// Split at 4 seconds
if let (first, second) = clip.split(at: 4) {
    // first: 0-4s, second: 4-10s
}

// Trim
clip.trim(start: 2, duration: 6) // now 2-8s
```

### Captions / SRT Import-Export

```swift
import VideoEditorCore

// Parse SRT
let srt = """
1
00:00:01,000 --> 00:00:03,500
Hello World

2
00:00:05,000 --> 00:00:08,200
Second caption
"""
let track = CaptionTrack.fromSRT(srt)

// Export back to SRT
let exported = track.toSRT()
```

### Export with Progress

```swift
import VideoEditorExport

let session = ExportSession()

try await session.export(
    project: project,
    preset: .hd1080p,
    outputURL: outputURL,
    progress: { progress in
        print("Export: \(Int(progress.fractionCompleted * 100))%")
    }
)

// Cancel if needed
session.cancel()
```

### SwiftUI Editor

```swift
import SwiftUI
import VideoEditorSwiftUI
import VideoEditorCore

struct ContentView: View {
    @State private var project = Project(name: "My Project")
    
    var body: some View {
        VideoEditorView(project: $project)
    }
}
```

### Composable SwiftUI Pieces

```swift
import SwiftUI
import VideoEditorSwiftUI
import VideoEditorCore

struct CustomEditor: View {
    @State private var project = Project(name: "Custom")
    @State private var currentTime: Double = 0
    
    var body: some View {
        VStack {
            PreviewView(project: $project, currentTime: $currentTime)
            
            ProjectTimelineView(
                project: $project,
                currentTime: $currentTime,
                onClipSelected: { clip in
                    print("Selected: \(clip.id)")
                }
            )
            
            ExportButton(
                project: project,
                preset: .hd1080p,
                outputURL: outputURL
            ) { result in
                switch result {
                case .success(let url): print("Exported to \(url)")
                case .failure(let error): print("Failed: \(error)")
                }
            }
        }
    }
}
```

## Data Model (Timeline-First)

The data model is designed to be serializable and deterministic:

- **Project** — canvasSize, fps, audioSampleRate, tracks
- **Track** — type (video/audio/overlay), clips, isMuted, isLocked
- **Clip** — type, timeRange, sourceURL, transform, opacity, volume, effects, isMuted
- **Effect** — type, parameters (Codable data, rendered by Engine)
- **Transition** — type, duration
- **ClipTransform** — position, scale, rotation, anchor
- **CaptionTrack** — SRT-compatible captions with import/export

All models conform to `Codable` and `Sendable`, enabling JSON save/load and thread-safe usage.

## Effects System (Extensible)

Effects are data + renderer: the `Effect` struct is Codable config, and `EffectRenderer` in the Engine maps effect types to CoreImage filters:

```swift
// Define effect (data-only, Codable)
let effect = Effect.colorControls(brightness: 0.1, contrast: 1.2, saturation: 0.8)

// Render via engine
import VideoEditorEngine
let renderer = EffectRenderer()
let output = renderer.apply(effect: effect, to: inputImage)
```

Built-in effects: sepia, blackAndWhite, brightness, contrast, saturation, blur, sharpen, vignette, colorControls, customLUT.

## Export Presets

| Preset | Resolution | Bitrate | Codec |
|--------|-----------|---------|-------|
| `.hd720p` | 1280×720 | 5 Mbps | H.264 |
| `.hd1080p` | 1920×1080 | 8 Mbps | H.264 |
| `.hd4K` | 3840×2160 | 20 Mbps | H.265 |
| `.instagram` | 1080×1080 | 5 Mbps | H.264 |
| `.twitter` | 1280×720 | 5 Mbps | H.264 |
| `.portrait` | 1080×1920 | 8 Mbps | H.264 |

Custom presets:

```swift
let custom = ExportPreset(
    resolution: CanvasSize(width: 1920, height: 1080),
    bitrate: 10_000_000,
    fps: 60,
    codec: .h265
)
```

## Error Handling

```swift
import VideoEditorCore

do {
    let json = try project.toJSON()
} catch VideoEditorError.serializationFailed(let msg) {
    print("Serialization failed: \(msg)")
} catch VideoEditorError.invalidAsset {
    print("Invalid asset")
} catch VideoEditorError.exportFailed(let msg) {
    print("Export failed: \(msg)")
} catch VideoEditorError.cancelled {
    print("Operation cancelled")
} catch {
    print("Error: \(error)")
}
```

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 15.0+

## Building

```bash
swift build
```

## Testing

```bash
swift test
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  ApertureSDK                     │
│              (umbrella re-export)                 │
├──────────────┬──────────────┬───────────────────┤
│ VideoEditor  │ VideoEditor  │  VideoEditor       │
│   SwiftUI    │   Export     │    Assets           │
├──────────────┴──────────────┤                    │
│       VideoEditorEngine      │                    │
│   (AVFoundation + CoreImage) │                    │
├──────────────────────────────┴───────────────────┤
│              VideoEditorCore                      │
│        (Pure Swift models, Codable)               │
└─────────────────────────────────────────────────┘
```

- **VideoEditorCore**: Pure Swift — no Apple framework dependencies beyond Foundation
- **VideoEditorEngine**: AVFoundation + CoreImage for rendering and asset management
- **VideoEditorExport**: Export pipeline with AVAssetExportSession
- **VideoEditorSwiftUI**: Thin SwiftUI wrappers over Core + Engine
- **VideoEditorAssets**: LUT/resource loading via `Bundle.module`
- Modern **async/await** concurrency throughout

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.