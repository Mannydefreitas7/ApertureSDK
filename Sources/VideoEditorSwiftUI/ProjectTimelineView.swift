#if canImport(AVFoundation) && canImport(SwiftUI)
import SwiftUI
import AVFoundation
import VideoEditorCore

/// SwiftUI view for project timeline representation
@available(iOS 15.0, macOS 12.0, *)
public struct ProjectTimelineView: View {
    @Binding var project: Project
    @Binding var currentTime: Double
    var onClipSelected: ((Clip) -> Void)?
    
    @State private var selectedClipId: UUID?
    @State private var scale: CGFloat = 1.0
    
    public init(
        project: Binding<Project>,
        currentTime: Binding<Double>,
        onClipSelected: ((Clip) -> Void)? = nil
    ) {
        self._project = project
        self._currentTime = currentTime
        self.onClipSelected = onClipSelected
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Timeline header
            HStack {
                Text("Timeline")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { scale = max(0.5, scale - 0.1) }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    
                    Text("\(Int(scale * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                    
                    Button(action: { scale = min(3.0, scale + 0.1) }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Playhead
            GeometryReader { geometry in
                let totalDuration = project.totalDuration
                let playheadPosition = totalDuration > 0
                    ? CGFloat(currentTime / totalDuration) * geometry.size.width
                    : 0
                
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)
                    .offset(x: playheadPosition)
                    .frame(height: geometry.size.height, alignment: .top)
            }
            .frame(height: 4)
            
            // Tracks
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(project.tracks) { track in
                        TrackRowView(
                            track: track,
                            scale: scale,
                            selectedClipId: $selectedClipId,
                            onClipSelected: onClipSelected
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .frame(minHeight: 120)
            .background(Color.gray.opacity(0.1))
            
            // Timeline info footer
            HStack {
                Text("Duration: \(formatDuration(project.totalDuration))")
                    .font(.caption)
                
                Spacer()
                
                let clipCount = project.tracks.reduce(0) { $0 + $1.clips.count }
                Text("\(clipCount) clips")
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct TrackRowView: View {
    let track: Track
    let scale: CGFloat
    @Binding var selectedClipId: UUID?
    var onClipSelected: ((Clip) -> Void)?
    
    var body: some View {
        HStack(spacing: 4) {
            // Track label
            Text(trackLabel)
                .font(.caption2)
                .frame(width: 50, alignment: .leading)
                .foregroundColor(.secondary)
            
            // Clips
            HStack(spacing: 2) {
                ForEach(track.clips) { clip in
                    ClipView(
                        clip: clip,
                        scale: scale,
                        isSelected: selectedClipId == clip.id
                    )
                    .onTapGesture {
                        selectedClipId = clip.id
                        onClipSelected?(clip)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(height: 44)
    }
    
    private var trackLabel: String {
        switch track.type {
        case .video: return "Video"
        case .audio: return "Audio"
        case .overlay: return "Overlay"
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct ClipView: View {
    let clip: Clip
    let scale: CGFloat
    let isSelected: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(clipColor)
            .frame(width: clipWidth, height: 36)
            .overlay(
                Text(formatDuration(clip.timeRange.duration))
                    .font(.caption2)
                    .foregroundColor(.white)
                    .lineLimit(1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
            )
    }
    
    private var clipWidth: CGFloat {
        max(30, CGFloat(clip.timeRange.duration) * 20 * scale)
    }
    
    private var clipColor: Color {
        if isSelected { return .blue }
        switch clip.type {
        case .video: return .green
        case .audio: return .orange
        case .image: return .purple
        case .text: return .pink
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 1 {
            return String(format: "%.1fs", seconds)
        }
        return "\(Int(seconds))s"
    }
}
#endif
