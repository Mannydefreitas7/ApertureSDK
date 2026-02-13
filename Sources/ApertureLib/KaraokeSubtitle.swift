//
//  KaraokeSubtitle.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import SwiftUI
import AVFoundation

struct KaraokeSubtitle: Identifiable {
    let id: UUID
    var lyrics: [KaraokeLine]
    var style: KaraokeStyle
}

struct KaraokeLine: Identifiable {
    let id: UUID
    var text: String
    var words: [KaraokeWord]
    var startTime: CMTime
    var endTime: CMTime
}

struct KaraokeWord: Identifiable {
    let id: UUID
    var text: String
    var startTime: CMTime
    var endTime: CMTime
}

struct KaraokeStyle: Identifiable {
    let id: UUID
    var font: String = "PingFang SC"
    var fontSize: CGFloat = 36
    var normalColor: CGColor = .init(red: 1, green: 1, blue: 1, alpha: 1)
    var highlightColor: CGColor = .init(red: 1, green: 0.8, blue: 0, alpha: 1)
    var outlineColor: CGColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
    var outlineWidth: CGFloat = 2
    var glowColor: CGColor?
    var glowRadius: CGFloat = 0
    var position: CGPoint = CGPoint(x: 0.5, y: 0.9)
    var highlightStyle: KaraokeHighlightStyle = .fillLeft
}

enum KaraokeHighlightStyle: String, Codable, CaseIterable {
    case fillLeft = "Fill Left"
    case fillRight = "Fill Right"
    case grow = "Grow"
    case glow = "Glow"
    case colorChange = "Color Change"
}
