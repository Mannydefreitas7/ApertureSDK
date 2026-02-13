//
//  HandwritingStyle.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import Foundation
import ApertureCore

extension HandwritingSubtitle {
    enum Style: String, Codable, CaseIterable {
        case natural = "Natural"
        case neat = "Neat"
        case calligraphy = "Calligraphy"
        case childish = "Childish"
    }
}


