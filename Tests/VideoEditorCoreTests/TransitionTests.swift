import XCTest
@testable import VideoEditorCore

final class TransitionTests: XCTestCase {
    
    func testTransitionFactoryMethods() {
        let crossDissolve = Transition.crossDissolve(duration: 1.0)
        XCTAssertEqual(crossDissolve.type, .crossDissolve)
        XCTAssertEqual(crossDissolve.duration, 1.0)
        
        let slide = Transition.slideLeft(duration: 0.5)
        XCTAssertEqual(slide.type, .slideLeft)
        XCTAssertEqual(slide.duration, 0.5)
        
        let fade = Transition.fade(duration: 0.3)
        XCTAssertEqual(fade.type, .fade)
        XCTAssertEqual(fade.duration, 0.3)
    }
    
    func testTransitionCodable() throws {
        let transition = Transition.crossDissolve(duration: 1.5)
        
        let data = try JSONEncoder().encode(transition)
        let decoded = try JSONDecoder().decode(Transition.self, from: data)
        
        XCTAssertEqual(decoded.type, .crossDissolve)
        XCTAssertEqual(decoded.duration, 1.5)
    }
}
