import Foundation
import Testing
@testable import VideoEditorCore

struct EffectTests {
    
    @Test func effectFactoryMethods() {
        let sepia = Effect.sepia(intensity: 0.5)
        #expect(sepia.type == .sepia)
        #expect(sepia.parameters["intensity"] == 0.5)
        #expect(sepia.isEnabled)
        
        let bw = Effect.blackAndWhite()
        #expect(bw.type == .blackAndWhite)
        
        let brightness = Effect.brightness(0.3)
        #expect(brightness.type == .brightness)
        #expect(brightness.parameters["value"] == 0.3)
        
        let contrast = Effect.contrast(1.5)
        #expect(contrast.type == .contrast)
        #expect(contrast.parameters["value"] == 1.5)
        
        let saturation = Effect.saturation(0.7)
        #expect(saturation.type == .saturation)
        #expect(saturation.parameters["value"] == 0.7)
        
        let blur = Effect.blur(radius: 10)
        #expect(blur.type == .blur)
        #expect(blur.parameters["radius"] == 10)
        
        let sharpen = Effect.sharpen(intensity: 0.8)
        #expect(sharpen.type == .sharpen)
        #expect(sharpen.parameters["intensity"] == 0.8)
        
        let vignette = Effect.vignette(intensity: 1.0, radius: 2.0)
        #expect(vignette.type == .vignette)
        #expect(vignette.parameters["intensity"] == 1.0)
        #expect(vignette.parameters["radius"] == 2.0)
    }
    
    @Test func effectCodable() throws {
        let effect = Effect.colorControls(brightness: 0.1, contrast: 1.2, saturation: 0.8)
        
        let data = try JSONEncoder().encode(effect)
        let decoded = try JSONDecoder().decode(Effect.self, from: data)
        
        #expect(decoded.type == Effect.EffectType.colorControls)
        #expect(decoded.parameters["brightness"] == 0.1)
        #expect(decoded.parameters["contrast"] == 1.2)
        #expect(decoded.parameters["saturation"] == 0.8)
        #expect(decoded.isEnabled)
    }
}
