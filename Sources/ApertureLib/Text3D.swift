//
//  Text3D.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import Foundation
import CoreGraphics

struct Text3D: Identifiable {
    let id: UUID
    var text: String
    var font: String
    var fontSize: CGFloat
    var depth: CGFloat
    var bevel: CGFloat
    var rotation: SIMD3<Float>
    var color: CGColor
    var lightingIntensity: Float
    var shadowEnabled: Bool
}
