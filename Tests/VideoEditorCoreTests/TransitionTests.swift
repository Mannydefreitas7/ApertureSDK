import Foundation
import Testing
@testable import VideoEditorCore

struct TransitionTests {
    
    @Test func transitionFactoryMethods() {
        let crossDissolve = Transition.crossDissolve(duration: 1.0)
        #expect(crossDissolve.type == .crossDissolve)
        #expect(crossDissolve.duration == 1.0)
        
        let slide = Transition.slideLeft(duration: 0.5)
        #expect(slide.type == .slideLeft)
        #expect(slide.duration == 0.5)
        
        let fade = Transition.fade(duration: 0.3)
        #expect(fade.type == .fade)
        #expect(fade.duration == 0.3)
    }
    
    @Test func transitionCodable() throws {
        let transition = Transition.crossDissolve(duration: 1.5)
        
        let data = try JSONEncoder().encode(transition)
        let decoded = try JSONDecoder().decode(Transition.self, from: data)
        
        #expect(decoded.type == Transition.TransitionType.crossDissolve)
        #expect(decoded.duration == 1.5)
    }
}
