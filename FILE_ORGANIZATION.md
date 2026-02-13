# ApertureSDK File Organization

This document provides an overview of the organized file structure after the refactoring effort.

## Core Module (ApertureCore)

### Primary Models
These are the main, unified models used throughout the SDK:

| File | Type | Purpose | Status |
|------|------|---------|--------|
| `Project.swift` | `struct` | Main project container with tracks and settings | ✅ Primary |
| `Transition.swift` | `struct` | Unified transition model with all types | ✅ Primary |
| `Track.swift` | `struct` | Timeline track containing clips | ✅ Primary |
| `Clip.swift` | `struct` | Media clip on a track | ✅ Primary |
| `Effect.swift` | `struct` | Visual effects configuration | ✅ Primary |

### Supporting Models

| File | Type | Purpose |
|------|------|---------|
| `ClipTimeRange.swift` | `struct` | Time range for clips |
| `ClipTransform.swift` | `struct` | Transformation properties for clips |
| `TextClipContent.swift` | `struct` | Content for text clips |
| `CanvasSize.swift` | `enum` | Video canvas size presets |
| `Caption.swift` | `struct` | Caption/subtitle data |
| `Timeline.swift` | `class` | Timeline management |
| `VideoAsset.swift` | `class` | Video asset wrapper |
| `VideoEditorError.swift` | `enum` | Error types |

### Extensions

| File | Purpose |
|------|---------|
| `Extensions/Track+Methods.swift` | Track manipulation methods |
| `Extensions/Clip.swift` | Clip editing operations |
| `Extensions/Project.swift` | Legacy project model (deprecated) |

### Managers

| File | Type | Purpose |
|------|------|---------|
| `ProjectManager.swift` | `class` | Project file management |
| `ExportManager.swift` | `class` | Video export functionality |
| `TemplateSystem.swift` | `struct` | Project templates |
| `SubtitleEnhanced.swift` | `struct` | Enhanced subtitle support |
| `AccessibilityFeatures.swift` | `struct` | Accessibility features |

### Audio

| File | Type | Purpose |
|------|------|---------|
| `AudioMixer.swift` | `class` | Audio mixing |
| `AudioProcessor.swift` | `class` | Audio processing |

### Video Effects

| File | Type | Purpose |
|------|------|---------|
| `VideoEffects.swift` | Various structs | Picture-in-picture, chroma key, effects |

---

## Assets Module (ApertureAssets)

### Text Overlays

| File | Type | Purpose | Status |
|------|------|---------|--------|
| `TextOverlays.swift` | `UnifiedTextOverlay` | Unified text overlay model with styling | ✅ Primary |

### Transitions

| File | Type | Purpose | Status |
|------|------|---------|--------|
| `Transition.swift` | `TransitionInstructionBuilder` | AVFoundation transition rendering | ✅ Active |

### Effects

| File | Type | Purpose |
|------|------|---------|
| `EffectProtocol.swift` | `protocol` | Protocol for effects |
| `FilterEffect.swift` | `struct` | Video filter effects |
| `StickersEffects.swift` | Various | Sticker and particle effects |

### Overlays

| File | Type | Purpose |
|------|------|---------|
| `OverlayProtocol.swift` | `protocol` | Protocol for overlays |
| `ImageOverlay.swift` | `class` | Image overlay support |

### Asset Management

| File | Type | Purpose |
|------|------|---------|
| `ResourceManager.swift` | `class` | Resource file management |
| `VideoImporter.swift` | `class` | Video import functionality |
| `LUTLoader.swift` | `class` | LUT (color grading) loading |

---

## Engine Module (ApertureEngine)

### Core Engine

| File | Type | Purpose |
|------|------|---------|
| `RenderEngine.swift` | `class` | Main rendering engine |
| `VideoEngine.swift` | `class` | Video playback and control |
| `AudioEngine.swift` | `class` | Audio playback engine |
| `EffectRenderer.swift` | `class` | Effect rendering system |

### Composition

| File | Type | Purpose |
|------|------|---------|
| `CompositionBuilder.swift` | `class` | AVComposition building |
| `AssetLoader.swift` | `class` | Asset loading utilities |

### Editing Tools

| File | Type | Purpose |
|------|------|---------|
| `VideoEditor.swift` | `class` | High-level editing operations |
| `VideoTrimmer.swift` | `class` | Video trimming |
| `VideoMerger.swift` | `class` | Video merging |
| `VideoSplitter.swift` | `class` | Video splitting |

### Advanced Features

| File | Type | Purpose |
|------|------|---------|
| `VideoEditingEnhanced.swift` | Various | Enhanced editing features |
| `UndoManager.swift` | `class` | Undo/redo functionality |
| `UIEnhancements.swift` | Various | UI enhancement utilities |

### Utilities

| File | Type | Purpose |
|------|------|---------|
| `AVFoundation+Sendable.swift` | `extension` | Sendable conformance for AVFoundation |

---

## Export Module (ApertureExport)

| File | Type | Purpose |
|------|------|---------|
| `VideoExporter.swift` | `class` | Basic video export |
| `AdvancedExporter.swift` | `class` | Advanced export features |
| `ExportSession.swift` | `class` | Export session management |
| `ExportPreset.swift` | `struct` | Export quality presets |
| `SocialMediaPreset.swift` | `struct` | Social media format presets |

---

## UI Module (ApertureUI)

### Cross-Platform Views

| File | Type | Purpose |
|------|------|---------|
| `VideoPlayerView.swift` | `View` | Video playback view |
| `TimelineView.swift` | `View` | Timeline visualization |
| `ProjectTimelineView.swift` | `View` | Project timeline editor |
| `TrimmerView.swift` | `View` | Video trimming UI |
| `ClipInspectorView.swift` | `View` | Clip property inspector |
| `ExportButton.swift` | `View` | Export UI button |
| `VideoEditorView.swift` | `View` | Main editor view |
| `PreviewView.swift` | `View` | Video preview component |

### macOS-Specific

| File | Type | Purpose |
|------|------|---------|
| `macOS/Views/MainEditorView.swift` | `View` | macOS main editor |
| `macOS/Views/TimelineView.swift` | `View` | macOS timeline |
| `macOS/Views/TransitionPanelView.swift` | `View` | Transition selection panel |
| `macOS/Views/TextEditorView.swift` | `View` | Text editing panel |
| `macOS/Views/MediaLibraryView.swift` | `View` | Media library browser |
| `macOS/Views/AdvancedPanels.swift` | `View` | Advanced editing panels |

### iOS-Specific

| File | Type | Purpose |
|------|------|---------|
| `iOS/Views/iOSEditorView.swift` | `View` | iOS main editor |
| `iOS/Views/CompactTimelineView.swift` | `View` | Compact timeline for iOS |

---

## AI Module (ApertureAI)

| File | Type | Purpose |
|------|------|---------|
| `AIFeatures.swift` | Various | AI-powered features |
| `AIAdvancedFeatures.swift` | Various | Advanced AI capabilities |

---

## SDK Module (ApertureSDK)

| File | Type | Purpose |
|------|------|---------|
| `ApertureSDK.swift` | `class` | Main SDK entry point |
| `ApertureError.swift` | `enum` | SDK error types |
| `Configuration.swift` | `struct` | SDK configuration |

---

## Tests

### Unit Tests

| File | Purpose |
|------|---------|
| `ApertureSDKTests.swift` | SDK initialization tests |
| `ApertureErrorTests.swift` | Error handling tests |
| `VideoMergerTests.swift` | Video merging tests |
| `VideoProjectTests.swift` | Project tests |
| `VideoTrimmerTests.swift` | Trimming tests |

### Core Model Tests

| File | Purpose |
|------|---------|
| `ProjectTests.swift` | Project model tests |
| `TrackTests.swift` | Track model tests |
| `ClipTests.swift` | Clip model tests |
| `EffectTests.swift` | Effect tests |
| `TransitionTests.swift` | Transition tests |
| `CaptionTests.swift` | Caption tests |
| `CompoundClipTests.swift` | Compound clip tests |
| `ModelTests.swift` | General model tests |

---

## Documentation Files

| File | Purpose |
|------|---------|
| `README.md` | Main SDK documentation |
| `EXAMPLES.md` | Code examples and usage |
| `LICENSE` | Software license |
| `REFACTORING_SUMMARY.md` | Refactoring details (NEW) |
| `MIGRATION_GUIDE.md` | Migration instructions (NEW) |
| `FILE_ORGANIZATION.md` | This file (NEW) |

---

## Build Configuration

| File | Purpose |
|------|---------|
| `Package.swift` | Swift Package Manager manifest |

---

## Model Hierarchy Summary

### Core Data Models (Codable, Sendable)
```
Project
├── Track[]
│   └── Clip[]
│       ├── Effect[]
│       ├── ClipTransform
│       ├── ClipTimeRange
│       ├── TextClipContent?
│       └── Track[]? (sub-timeline)
├── Transition[]
└── CanvasSize
```

### Asset Models
```
UnifiedTextOverlay
├── TextStyle
│   ├── FontWeight
│   ├── TextAlignment
│   └── CodableColor
├── TextPosition
└── TextAnimation
```

---

## Deleted Files

The following duplicate/legacy files have been removed during refactoring:

| File | Reason for Removal | Replacement |
|------|-------------------|-------------|
| `ApertureAssets/TransitionEffect.swift` | Duplicate functionality | `Transition` (ApertureCore) |
| `ApertureAssets/TextOverlay.swift` | Duplicate functionality | `UnifiedTextOverlay` (TextOverlays.swift) |
| `ApertureCore/Extensions/Project.swift` | Duplicate model | `Project` (ApertureCore) |
| `ApertureCore/Extensions/Clip.swift` | Incompatible methods | Built-in methods in `Clip` |

---

## Quick Reference: Where to Find Things

### Need to...
- **Create a project?** → `ApertureCore.Project`
- **Add transitions?** → `ApertureCore.Transition`
- **Add text overlays?** → `ApertureAssets.UnifiedTextOverlay`
- **Apply effects?** → `ApertureCore.Effect`
- **Manage tracks?** → `ApertureCore.Track`
- **Handle clips?** → `ApertureCore.Clip`
- **Render video?** → `ApertureEngine.RenderEngine`
- **Export video?** → `ApertureExport.VideoExporter`
- **Build UI?** → `ApertureUI.*View`
- **Use AI features?** → `ApertureAI.AIFeatures`

---

**Last Updated**: February 12, 2026
**ApertureSDK Version**: 2.0+
