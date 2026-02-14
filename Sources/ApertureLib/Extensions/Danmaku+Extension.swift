//
//  DanmakuType.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation
import ApertureCore

// MARK: - Danmaku Subtitles

extension DanmakuSubtitle {

    enum Style: String, Codable, CaseIterable {
        case scroll = "Scroll"
        case top = "Top Fixed"
        case bottom = "Bottom Fixed"
    }

}


