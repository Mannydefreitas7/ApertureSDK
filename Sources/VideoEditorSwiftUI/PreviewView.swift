#if canImport(AVFoundation) && canImport(SwiftUI)
import SwiftUI
import AVKit
import AVFoundation
import VideoEditorCore
import VideoEditorEngine

/// A lower-level preview view for displaying rendered frames
@available(iOS 15.0, macOS 12.0, *)
public struct PreviewView: View {
    private let engine: RenderEngine
    @Binding var project: Project
    @Binding var currentTime: Double
    
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    
    public init(
        engine: RenderEngine = RenderEngine(),
        project: Binding<Project>,
        currentTime: Binding<Double>
    ) {
        self.engine = engine
        self._project = project
        self._currentTime = currentTime
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
    }
}
#endif
