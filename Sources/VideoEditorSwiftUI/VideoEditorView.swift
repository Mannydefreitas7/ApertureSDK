#if canImport(AVFoundation) && canImport(SwiftUI)
import SwiftUI
import VideoEditorCore
import VideoEditorEngine

/// Main video editor view composing preview, timeline, and inspector
@available(iOS 15.0, macOS 12.0, *)
public struct VideoEditorView: View {
    @Binding var project: Project
    @State private var currentTime: Double = 0
    @State private var selectedClip: Clip?
    @State private var showInspector: Bool = false
    
    private let engine: RenderEngine
    
    public init(project: Binding<Project>, engine: RenderEngine = RenderEngine()) {
        self._project = project
        self.engine = engine
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Preview area
            PreviewView(
                engine: engine,
                project: $project,
                currentTime: $currentTime
            )
            .frame(minHeight: 200)
            
            Divider()
            
            // Playback controls
            HStack {
                Button(action: {
                    currentTime = 0
                }) {
                    Image(systemName: "backward.end.fill")
                }
                
                Button(action: {
                    // Toggle play/pause - would be connected to engine
                }) {
                    Image(systemName: "play.fill")
                }
                
                Slider(
                    value: $currentTime,
                    in: 0...max(project.totalDuration, 0.01)
                )
                
                Text(formatTime(currentTime))
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Timeline
            ProjectTimelineView(
                project: $project,
                currentTime: $currentTime,
                onClipSelected: { clip in
                    selectedClip = clip
                    showInspector = true
                }
            )
            .frame(minHeight: 150)
        }
        .sheet(isPresented: $showInspector) {
            if var clip = selectedClip {
                ClipInspectorView(
                    clip: Binding(
                        get: { clip },
                        set: { newClip in
                            clip = newClip
                            updateClipInProject(newClip)
                        }
                    ),
                    onDelete: {
                        deleteClip(clip)
                        showInspector = false
                    }
                )
            }
        }
    }
    
    private func updateClipInProject(_ updatedClip: Clip) {
        for trackIndex in project.tracks.indices {
            if let clipIndex = project.tracks[trackIndex].clips.firstIndex(where: { $0.id == updatedClip.id }) {
                project.tracks[trackIndex].clips[clipIndex] = updatedClip
                break
            }
        }
    }
    
    private func deleteClip(_ clip: Clip) {
        for trackIndex in project.tracks.indices {
            project.tracks[trackIndex].clips.removeAll { $0.id == clip.id }
        }
        selectedClip = nil
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
#endif
