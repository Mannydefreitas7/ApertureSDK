//
//  HandwritingAnimation.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import CoreGraphics
import Foundation
// Use Title3DRenderer for rendering (implemented in EffectsEnhanced)

// MARK: - Handwriting Animation

struct HandwritingAnimation: Identifiable {
    let id: UUID
    var text: String
    var font: String
    var fontSize: CGFloat
    var color: CGColor
    var strokeWidth: CGFloat
    var duration: Double
    var style: HandwritingStyle
}
