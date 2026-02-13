import Foundation
import ApertureCore

/// Represents a visual effect applied to a clip (data-only, Codable)
public struct AdjustmentEffect: Effect {
    public var id: UUID
    public var type: EffectType
    public var parameters: [String: Double]
    public var isEnabled: Bool
    
    // MARK: - Factory Methods
    
    public static func sepia(intensity: Double = 0.8) -> Effect {
        Effect(type: .sepia, parameters: ["intensity": intensity])
    }
    
    public static func blackAndWhite() -> Effect {
        Effect(type: .blackAndWhite)
    }
    
    public static func brightness(_ value: Double) -> Effect {
        Effect(type: .brightness, parameters: ["value": value])
    }
    
    public static func contrast(_ value: Double) -> Effect {
        Effect(type: .contrast, parameters: ["value": value])
    }
    
    public static func saturation(_ value: Double) -> Effect {
        Effect(type: .saturation, parameters: ["value": value])
    }
    
    public static func blur(radius: Double) -> Effect {
        Effect(type: .blur, parameters: ["radius": radius])
    }
    
    public static func sharpen(intensity: Double) -> Effect {
        Effect(type: .sharpen, parameters: ["intensity": intensity])
    }
    
    public static func vignette(intensity: Double = 1.0, radius: Double = 1.0) -> Effect {
        Effect(type: .vignette, parameters: ["intensity": intensity, "radius": radius])
    }
    
    public static func colorControls(brightness: Double = 0, contrast: Double = 1, saturation: Double = 1) -> Effect {
        Effect(type: .colorControls, parameters: ["brightness": brightness, "contrast": contrast, "saturation": saturation])
    }
}
