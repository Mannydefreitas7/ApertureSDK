#if canImport(AVFoundation) && canImport(SwiftUI)
import SwiftUI
import AVKit
import AVFoundation
import ApertureCore
import ApertureEngine

/// A lower-level preview view for displaying rendered frames.
///
/// Builds a playable composition from the project timeline and uses
/// AVPlayer for playback, seeking to `currentTime` when it changes.
@available(iOS 15.0, macOS 12.0, *)
public struct PreviewView: View {
    private let engine: RenderEngine
    @Binding var project: Project
    @Binding var currentTime: Double
    
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    
    private let compositionBuilder: CompositionBuilder
    
    public init(
        engine: RenderEngine = RenderEngine(),
        project: Binding<Project>,
        currentTime: Binding<Double>
    ) {
        self.engine = engine
        self._project = project
        self._currentTime = currentTime
        self.compositionBuilder = CompositionBuilder()
    }
    
    public var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        Text("No Preview")
                            .foregroundColor(.gray)
                    )
            }
        }
        .aspectRatio(
            CGFloat(project.canvasSize.width / max(project.canvasSize.height, 1)),
            contentMode: .fit
        )
        .task(id: trackFingerprint) {
            await buildPlayerFromProject()
        }
        .onChange(of: currentTime) { newTime in
            guard let player = player, !isPlaying else { return }
            let cmTime = CMTime(seconds: newTime, preferredTimescale: 600)
            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }
    
    /// Stable fingerprint of the track layout that re-triggers the preview build
    /// when clips are added, removed, or reordered. Uses track/clip IDs and counts
    /// to avoid hash collisions.
    private var trackFingerprint: String {
        project.tracks.map { track in
            "\(track.id):\(track.clips.map { $0.id.uuidString }.joined(separator: ","))"
        }.joined(separator: "|")
    }
    
    @MainActor
    private func buildPlayerFromProject() async {
        // Only build if there are clips to play
        let hasClips = project.tracks.contains { !$0.clips.isEmpty }
        guard hasClips else {
            player = nil
            return
        }
        
        do {
            let composition = try await compositionBuilder.buildComposition(from: project)
            let playerItem = AVPlayerItem(asset: composition)
            let newPlayer = AVPlayer(playerItem: playerItem)
            player = newPlayer
        } catch {
            player = nil
        }
    }
}
#endif
