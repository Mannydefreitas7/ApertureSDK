#if canImport(AVFoundation) && canImport(SwiftUI)
import SwiftUI
import VideoEditorCore
import VideoEditorExport

/// A reusable export button with progress display
@available(iOS 15.0, macOS 12.0, *)
public struct ExportButton: View {
    let project: Project
    let preset: ExportPreset
    let outputURL: URL
    var onComplete: ((Result<URL, Error>) -> Void)?
    
    @State private var isExporting: Bool = false
    @State private var progress: Double = 0
    @State private var exportSession: ExportSession?
    
    public init(
        project: Project,
        preset: ExportPreset = .hd1080p,
        outputURL: URL,
        onComplete: ((Result<URL, Error>) -> Void)? = nil
    ) {
        self.project = project
        self.preset = preset
        self.outputURL = outputURL
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack {
            if isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                    
                    HStack {
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Button("Cancel") {
                            cancelExport()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            } else {
                Button(action: startExport) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
    
    private func startExport() {
        isExporting = true
        progress = 0
        let session = ExportSession()
        exportSession = session
        
        Task {
            do {
                try await session.export(
                    project: project,
                    preset: preset,
                    outputURL: outputURL,
                    progress: { exportProgress in
                        Task { @MainActor in
                            progress = exportProgress.fractionCompleted
                        }
                    }
                )
                await MainActor.run {
                    isExporting = false
                    onComplete?(.success(outputURL))
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    onComplete?(.failure(error))
                }
            }
        }
    }
    
    private func cancelExport() {
        exportSession?.cancel()
        isExporting = false
        progress = 0
    }
}
#endif
