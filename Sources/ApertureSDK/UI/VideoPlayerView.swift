#if canImport(AVFoundation)
import SwiftUI
import AVKit
import AVFoundation

/// SwiftUI view for video playback
@available(iOS 15.0, macOS 12.0, *)
public struct VideoPlayerView: View {
    @Binding public var asset: VideoAsset
    @Binding public var currentTime: CMTime
    public var showControls: Bool
    
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    
    /// Initialize a video player view
    /// - Parameters:
    ///   - asset: Binding to the video asset
    ///   - currentTime: Binding to the current playback time
    ///   - showControls: Whether to show playback controls
    public init(
        asset: Binding<VideoAsset>,
        currentTime: Binding<CMTime>,
        showControls: Bool = true
    ) {
        self._asset = asset
        self._currentTime = currentTime
        self.showControls = showControls
    }
    
    public var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        setupPlayer()
                    }
                
                if showControls {
                    HStack {
                        Button(action: togglePlayback) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        }
                        
                        Slider(
                            value: Binding(
                                get: { CMTimeGetSeconds(currentTime) },
                                set: { newValue in
                                    let newTime = CMTime(seconds: newValue, preferredTimescale: 600)
                                    player.seek(to: newTime)
                                    currentTime = newTime
                                }
                            ),
                            in: 0...CMTimeGetSeconds(asset.duration)
                        )
                        
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .padding()
                }
            } else {
                ProgressView()
                    .onAppear {
                        setupPlayer()
                    }
            }
        }
    }
    
    private func setupPlayer() {
        let playerItem = AVPlayerItem(asset: asset.avAsset)
        player = AVPlayer(playerItem: playerItem)
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func formatTime(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
#endif
