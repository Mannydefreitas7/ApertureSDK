# ApertureSDK Migration Guide

This guide helps you understand the changes made during the refactoring of ApertureSDK.

**Important**: Since this SDK is not yet in production use, all duplicate/legacy files have been **completely removed** rather than deprecated. This guide documents the unified models and best practices.

## Table of Contents
- [Transition Models](#transition-models)
- [TextOverlay Models](#textoverlay-models)
- [Project Models](#project-models)
- [General Best Practices](#general-best-practices)

---

## Transition Models

### Overview
Three separate transition implementations have been unified into a single `Transition` model in `ApertureCore`.

### Usage

#### Creating Transitions

```swift
import ApertureCore

// Using factory methods (recommended)
let transition = Transition.crossDissolve(duration: 1.0)
let fade = Transition.fade(duration: 0.5)
let zoom = Transition.zoom(duration: 0.75)

// Using initializer
let transition = Transition(
    type: .crossDissolve,
    duration: 0.5,
    fromClipId: clip1.id,
    toClipId: clip2.id
)
```

#### Using Transition with Builder

```swift
import ApertureCore
import ApertureAssets

let transition = Transition.fade(duration: 1.0)
let instruction = TransitionInstructionBuilder.buildInstruction(
    for: transition,
    fromTrack: fromTrack,
    toTrack: toTrack,
    at: time,
    renderSize: size
)
```

#### Available Transition Types

All transition types available:
- `.none` - No transition
- `.crossDissolve` - Cross dissolve effect
- `.fade` - Fade in/out
- `.slideLeft`, `.slideRight`, `.slideUp`, `.slideDown` - Slide transitions
- `.wipeLeft`, `.wipeRight`, `.wipeUp`, `.wipeDown` - Wipe transitions
- `.zoom` - Zoom effect
- `.blur` - Blur transition
- `.dissolve` - Dissolve effect

---

## TextOverlay Models

### Overview
The unified `UnifiedTextOverlay` model provides rich text styling and animation capabilities.

### Usage

#### Basic Text Overlay

```swift
import ApertureAssets

let overlay = UnifiedTextOverlay(
    text: "Hello World",
    style: TextStyle(
        fontSize: 48,
        textColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 1),
        alignment: .center
    ),
    position: .center,
    animation: .fadeInOut,
    timeRange: CMTimeRange(
        start: .zero,
        duration: CMTime(seconds: 5, preferredTimescale: 600)
    )
)
```

#### Advanced Text Styling

The `UnifiedTextOverlay` provides rich styling options:

```swift
let overlay = UnifiedTextOverlay(
    text: "Styled Text",
    style: TextStyle(
        fontName: "Helvetica",
        fontSize: 60,
        fontWeight: .bold,
        textColor: CodableColor(red: 1, green: 0.8, blue: 0, alpha: 1),
        backgroundColor: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.5),
        strokeColor: CodableColor(red: 0, green: 0, blue: 0, alpha: 1),
        strokeWidth: 2,
        shadowColor: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.7),
        shadowOffset: CGSize(width: 3, height: 3),
        shadowBlur: 5,
        letterSpacing: 2,
        lineSpacing: 10,
        alignment: .center
    ),
    position: .bottomCenter,
    animation: .slideUp,
    timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600))
)
```

#### Text Animations

Available animations:
- `.none` - No animation
- `.fadeIn` - Fade in
- `.fadeOut` - Fade out
- `.fadeInOut` - Fade in then out
- `.slideUp`, `.slideDown`, `.slideLeft`, `.slideRight` - Slide effects
- `.slideFromBottom` - Slide from bottom
- `.typewriter` - Typewriter effect
- `.scale` - Scale animation
- `.bounce` - Bounce effect
- `.pop` - Pop effect

#### Text Positions

Available positions:
- `.topLeft`, `.topCenter`, `.topRight`
- `.centerLeft`, `.center`, `.centerRight`
- `.bottomLeft`, `.bottomCenter`, `.bottomRight`
- `.custom` - Custom position

---

## Project Models

### Overview
The unified `Project` model in ApertureCore is the only project model.

### Usage

#### Creating Projects

```swift
import ApertureCore

var project = Project(
    name: "My Project",
    canvasSize: .hd1080p,
    fps: 30,
    audioSampleRate: 44100
)
```

#### Project Features

The `Project` model provides:
- **Codable**: Full JSON serialization support
- **Sendable**: Thread-safe for Swift concurrency
- **Track Management**: Add, remove, and manage tracks
- **Grouping**: Group and ungroup clips
- **Serialization**: Save and load projects

```swift
// Create project
var project = Project(name: "My Video")

// Add tracks
let videoTrack = Track(name: "Main Video", type: .video)
project.addTrack(videoTrack)

// Serialize
let jsonData = try project.toJSON()

// Deserialize
let loadedProject = try Project.fromJSON(jsonData)
```

---

## General Best Practices

### 1. Import the Right Modules

```swift
// For core models (Project, Transition, Track, Clip, Effect)
import ApertureCore

// For rendering and assets (UnifiedTextOverlay, TransitionInstructionBuilder)
import ApertureAssets

// For UI components
import ApertureUI
```

### 2. Use Factory Methods

Many models provide convenient factory methods:

```swift
// Transitions
let fade = Transition.fade(duration: 1.0)
let dissolve = Transition.dissolve(duration: 0.5)

// Effects
let sepia = Effect.sepia(intensity: 0.8)
let blur = Effect.blur(radius: 5.0)
```

### 3. Leverage Codable

All core models are now Codable:

```swift
// Save project
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let data = try encoder.encode(project)
try data.write(to: projectURL)

// Load project
let data = try Data(contentsOf: projectURL)
let decoder = JSONDecoder()
let project = try decoder.decode(Project.self, from: data)
```

### 4. Use Sendable for Concurrency

All models conform to Sendable for safe concurrent access:

```swift
actor ProjectManager {
    var projects: [Project] = []
    
    func addProject(_ project: Project) {
        projects.append(project)
    }
}
```

### 5. Handle Deprecations

Xcode will show warnings for deprecated APIs. Follow the deprecation messages:

```swift
// ⚠️ Deprecated
let effect = TransitionEffect(type: .fade, duration: duration)

// ✅ Recommended
let transition = Transition.fade(duration: 1.0)
```

---

## Changes Summary

### Unified APIs
1. **Transition duration**: Uses `Double` (seconds) for simplicity
2. **TextOverlay**: Uses struct-based `UnifiedTextOverlay` with rich features
3. **Project**: Single unified model in ApertureCore

### Removed Files
The following duplicate/legacy files have been completely removed:
- `ApertureAssets/TransitionEffect.swift`
- `ApertureAssets/TextOverlay.swift`
- `ApertureCore/Extensions/Project.swift`
- `ApertureCore/Extensions/Clip.swift`

---

## Need Help?

For more information:

1. Review the `REFACTORING_SUMMARY.md` for technical details
2. Look at the unit tests for usage examples
3. Refer to `EXAMPLES.md` for complete code samples
4. Check `FILE_ORGANIZATION.md` for file structure

---

**Last Updated**: February 12, 2026
**ApertureSDK Version**: 2.0+
