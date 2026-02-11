#if canImport(AVFoundation)
import SwiftUI
import AVFoundation

/// SwiftUI view for video trimming
@available(iOS 15.0, macOS 12.0, *)
public struct TrimmerView: View {
    @Binding public var asset: VideoAsset
    public var onTrimChanged: (CMTime, CMTime) -> Void
    
    @State private var startPosition: CGFloat = 0
    @State private var endPosition: CGFloat = 1
    @State private var thumbnails: [CGImage] = []
    
    private let thumbnailCount = 10
    
    /// Initialize a trimmer view
    /// - Parameters:
    ///   - asset: Binding to the video asset
    ///   - onTrimChanged: Callback when trim points change
    public init(
        asset: Binding<VideoAsset>,
        onTrimChanged: @escaping (CMTime, CMTime) -> Void
    ) {
        self._asset = asset
        self.onTrimChanged = onTrimChanged
    }
    
    public var body: some View {
        VStack {
            // Duration display
            HStack {
                Text("Start: \(formatTime(startTime))")
                    .font(.caption)
                
                Spacer()
                
                Text("Duration: \(formatTime(duration))")
                    .font(.caption)
                    .bold()
                
                Spacer()
                
                Text("End: \(formatTime(endTime))")
                    .font(.caption)
            }
            .padding(.horizontal)
            
            // Trimmer interface
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Thumbnail strip
                    HStack(spacing: 0) {
                        ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
                            Image(decorative: image, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width / CGFloat(thumbnailCount))
                        }
                    }
                    .frame(height: 60)
                    .clipped()
                    
                    // Overlay for trimmed region
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: startPosition * geometry.size.width)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: (1 - endPosition) * geometry.size.width)
                        .offset(x: endPosition * geometry.size.width)
                    
                    // Trim handles
                    TrimHandle(isStart: true)
                        .offset(x: startPosition * geometry.size.width - 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPosition = min(max(0, value.location.x / geometry.size.width), endPosition - 0.05)
                                    startPosition = newPosition
                                    updateTrimTimes()
                                }
                        )
                    
                    TrimHandle(isStart: false)
                        .offset(x: endPosition * geometry.size.width - 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPosition = min(max(startPosition + 0.05, value.location.x / geometry.size.width), 1)
                                    endPosition = newPosition
                                    updateTrimTimes()
                                }
                        )
                }
            }
            .frame(height: 60)
            .cornerRadius(8)
            .padding()
        }
        .task {
            await loadThumbnails()
        }
    }
    
    private var startTime: CMTime {
        let seconds = CMTimeGetSeconds(asset.duration) * Double(startPosition)
        return CMTime(seconds: seconds, preferredTimescale: 600)
    }
    
    private var endTime: CMTime {
        let seconds = CMTimeGetSeconds(asset.duration) * Double(endPosition)
        return CMTime(seconds: seconds, preferredTimescale: 600)
    }
    
    private var duration: CMTime {
        return CMTimeSubtract(endTime, startTime)
    }
    
    private func updateTrimTimes() {
        onTrimChanged(startTime, endTime)
    }
    
    private func loadThumbnails() async {
        guard #available(iOS 16, macOS 13, *) else { return }
        let duration = CMTimeGetSeconds(asset.duration)
        let interval = duration / Double(thumbnailCount)
        
        var loadedThumbnails: [CGImage] = []
        
        for i in 0..<thumbnailCount {
            let time = CMTime(seconds: interval * Double(i), preferredTimescale: 600)
            if let thumbnail = try? await asset.generateThumbnail(at: time) {
                loadedThumbnails.append(thumbnail)
            }
        }
        
        thumbnails = loadedThumbnails
    }
    
    private func formatTime(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, secs, ms)
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct TrimHandle: View {
    let isStart: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white)
            .frame(width: 20, height: 60)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .overlay(
                Image(systemName: isStart ? "chevron.right" : "chevron.left")
                    .foregroundColor(.blue)
                    .font(.caption)
            )
    }
}
#endif
