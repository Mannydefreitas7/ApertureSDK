#if canImport(SwiftUI)
import SwiftUI
import VideoEditorCore

/// Inspector view for editing clip properties
@available(iOS 15.0, macOS 12.0, *)
public struct ClipInspectorView: View {
    @Binding var clip: Clip
    var onDelete: (() -> Void)?
    
    public init(clip: Binding<Clip>, onDelete: (() -> Void)? = nil) {
        self._clip = clip
        self.onDelete = onDelete
    }
    
    public var body: some View {
        Form {
            Section("Clip Info") {
                HStack {
                    Text("Type")
                    Spacer()
                    Text(clip.type.rawValue.capitalized)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(String(format: "%.2fs", clip.timeRange.duration))
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Transform") {
                VStack(alignment: .leading) {
                    Text("Opacity: \(Int(clip.opacity * 100))%")
                    Slider(value: $clip.opacity, in: 0...1)
                }
                
                VStack(alignment: .leading) {
                    Text("Scale X: \(String(format: "%.1f", clip.transform.scaleX))")
                    Slider(value: $clip.transform.scaleX, in: 0.1...3.0)
                }
                
                VStack(alignment: .leading) {
                    Text("Scale Y: \(String(format: "%.1f", clip.transform.scaleY))")
                    Slider(value: $clip.transform.scaleY, in: 0.1...3.0)
                }
                
                VStack(alignment: .leading) {
                    Text("Rotation: \(Int(clip.transform.rotation))°")
                    Slider(value: $clip.transform.rotation, in: -180...180)
                }
            }
            
            Section("Audio") {
                VStack(alignment: .leading) {
                    Text("Volume: \(Int(clip.volume * 100))%")
                    Slider(value: $clip.volume, in: 0...1)
                }
                
                Toggle("Muted", isOn: $clip.isMuted)
            }
            
            if let onDelete = onDelete {
                Section {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Clip")
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}
#endif
