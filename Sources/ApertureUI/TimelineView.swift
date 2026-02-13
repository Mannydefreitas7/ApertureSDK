#if canImport(AVFoundation)
import SwiftUI
import AVFoundation

/// SwiftUI view for timeline representation
@available(iOS 15.0, macOS 12.0, *)
public struct TimelineView: View {
    @Binding public var project: VideoProject
    public var onAssetSelected: (VideoAsset) -> Void
    
    @State private var selectedAssetId: UUID?
    @State private var scale: CGFloat = 1.0
    
    /// Initialize a timeline view
    /// - Parameters:
    ///   - project: Binding to the video project
    ///   - onAssetSelected: Callback when an asset is selected
    public init(
        project: Binding<VideoProject>,
        onAssetSelected: @escaping (VideoAsset) -> Void
    ) {
        self._project = project
        self.onAssetSelected = onAssetSelected
    }
    
    public var body: some View {
        VStack {
            // Timeline header
            HStack {
                Text("Timeline")
                    .font(.headline)
                
                Spacer()
                
                HStack {
                    Button(action: { scale = max(0.5, scale - 0.1) }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    
                    Button(action: { scale = min(2.0, scale + 0.1) }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                }
            }
            .padding()
            
            // Timeline tracks
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(project.timeline.tracks, id: \.id) { track in
                        TimelineTrackView(
                            track: track,
                            scale: scale,
                            selectedAssetId: $selectedAssetId,
                            onAssetSelected: onAssetSelected
                        )
                    }
                }
                .padding()
            }
            .frame(height: 200)
            .background(Color.gray.opacity(0.1))
            
            // Timeline info
            HStack {
                Text("Duration: \(formatDuration(project.timeline.totalDuration))")
                    .font(.caption)
                
                Spacer()
                
                Text("\(project.assets.count) clips")
                    .font(.caption)
            }
            .padding(.horizontal)
        }
    }
    
    private func formatDuration(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct TimelineTrackView: View {
    let track: TimelineTrack
    let scale: CGFloat
    @Binding var selectedAssetId: UUID?
    let onAssetSelected: (VideoAsset) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(trackLabel)
                .font(.caption)
                .frame(width: 60, alignment: .leading)
            
            HStack(spacing: 2) {
                ForEach(track.clips, id: \.id) { clip in
                    TimelineClipView(
                        asset: clip,
                        scale: scale,
                        isSelected: selectedAssetId == clip.id
                    )
                    .onTapGesture {
                        selectedAssetId = clip.id
                        onAssetSelected(clip)
                    }
                }
            }
        }
        .frame(height: 50)
    }
    
    private var trackLabel: String {
        switch track.type {
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .overlay:
            return "Overlay"
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct TimelineClipView: View {
    let asset: VideoAsset
    let scale: CGFloat
    let isSelected: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? Color.blue : Color.green)
            .frame(width: clipWidth)
            .overlay(
                Text(formatDuration(asset.trimmedDuration))
                    .font(.caption2)
                    .foregroundColor(.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
            )
    }
    
    private var clipWidth: CGFloat {
        let seconds = CMTimeGetSeconds(asset.trimmedDuration)
        return CGFloat(seconds) * 20 * scale // 20 points per second base
    }
    
    private func formatDuration(_ time: CMTime) -> String {
        let seconds = Int(CMTimeGetSeconds(time))
        return "\(seconds)s"
    }
}
#endif
