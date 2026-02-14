//
//  CaptionStyle+Ptrotocol.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation

public protocol CaptionStyle {

    associatedtype CaptionStyleType: Hashable

    let id: UUID
    var type: CaptionStyleType
    var color: CGColor
    var fontSize: CGFloat
    var position: CGFloat  // 0-1, vertical position
    var speed: CGFloat
    var offset: CGFloat  // Offset along path
    var animated: Bool
    var animationDuration: Double?
}
