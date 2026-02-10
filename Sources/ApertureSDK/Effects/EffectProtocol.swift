#if canImport(AVFoundation)
import Foundation
import AVFoundation

/// Protocol for video effects
public protocol EffectProtocol {
    var id: UUID { get }
    var name: String { get }
    func apply(to composition: AVMutableVideoComposition) -> AVMutableVideoComposition
}
#endif
