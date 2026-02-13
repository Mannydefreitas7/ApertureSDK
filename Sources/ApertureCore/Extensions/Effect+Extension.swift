//
//  Effect+Extension.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation

extension Effect {

     enum AdjustmentType: String, Codable {
        case sepia
        case blackAndWhite
        case brightness
        case contrast
        case saturation
        case blur
        case sharpen
        case vignette
        case colorControls
        case customLUT
    }

}
