//
//  PathText.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation

struct TextPath: Identifiable {
    let id: UUID
    var text: String
    var font: String
    var fontSize: CGFloat
    var color: CodableColor
    var pathType: TextPathType
    var customPath: [CGPoint]?
    var offset: CGFloat  // Offset along path
    var animated: Bool
    var animationDuration: Double
}
