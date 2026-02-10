import XCTest
@testable import VideoEditorCore

final class EffectTests: XCTestCase {
    
    func testEffectFactoryMethods() {
        let sepia = Effect.sepia(intensity: 0.5)
        XCTAssertEqual(sepia.type, .sepia)
        XCTAssertEqual(sepia.parameters["intensity"], 0.5)
        XCTAssertTrue(sepia.isEnabled)
        
        let bw = Effect.blackAndWhite()
        XCTAssertEqual(bw.type, .blackAndWhite)
        
        let brightness = Effect.brightness(0.3)
        XCTAssertEqual(brightness.type, .brightness)
        XCTAssertEqual(brightness.parameters["value"], 0.3)
        
        let contrast = Effect.contrast(1.5)
        XCTAssertEqual(contrast.type, .contrast)
        XCTAssertEqual(contrast.parameters["value"], 1.5)
        
        let saturation = Effect.saturation(0.7)
        XCTAssertEqual(saturation.type, .saturation)
        XCTAssertEqual(saturation.parameters["value"], 0.7)
        
        let blur = Effect.blur(radius: 10)
        XCTAssertEqual(blur.type, .blur)
        XCTAssertEqual(blur.parameters["radius"], 10)
        
        let sharpen = Effect.sharpen(intensity: 0.8)
        XCTAssertEqual(sharpen.type, .sharpen)
        XCTAssertEqual(sharpen.parameters["intensity"], 0.8)
        
        let vignette = Effect.vignette(intensity: 1.0, radius: 2.0)
        XCTAssertEqual(vignette.type, .vignette)
        XCTAssertEqual(vignette.parameters["intensity"], 1.0)
        XCTAssertEqual(vignette.parameters["radius"], 2.0)
    }
    
    func testEffectCodable() throws {
        let effect = Effect.colorControls(brightness: 0.1, contrast: 1.2, saturation: 0.8)
        
        let data = try JSONEncoder().encode(effect)
        let decoded = try JSONDecoder().decode(Effect.self, from: data)
        
        XCTAssertEqual(decoded.type, .colorControls)
        XCTAssertEqual(decoded.parameters["brightness"], 0.1)
        XCTAssertEqual(decoded.parameters["contrast"], 1.2)
        XCTAssertEqual(decoded.parameters["saturation"], 0.8)
        XCTAssertTrue(decoded.isEnabled)
    }
}
