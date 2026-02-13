//
//  Danmaku.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import Foundation
import CoreMedia

struct Danmaku: Identifiable {
    let id: UUID
    var text: String
    var type: DanmakuType
    var color: CodableColor
    var fontSize: CGFloat
    var startTime: CMTime
    var duration: Double
    var position: CGFloat  // 0-1, vertical position
    var speed: CGFloat
}
