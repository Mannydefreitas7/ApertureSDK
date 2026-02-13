//
//  TextStyle.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation
import CoreGraphics
import SwiftUI
    /// Text style configuration
public struct TextStyle {
    public var fontName: String = "avenir-next-demibold"
    public var fontSize: CGFloat = 48
    public var fontWeight: FontWeight = .medium
    public var textColor: Color = .secondary
    public var strokeColor: Color? = nil
    public var strokeWidth: CGFloat = 0
    public var shadowColor: Color? = .clear
    public var shadowOffset: CGSize = CGSize(width: 2, height: 2)
    public var shadowBlur: CGFloat = 4
    public var letterSpacing: CGFloat = 0
    public var lineSpacing: CGFloat = 0
    public var alignment: TextAlignment = .center

        /// Get platform font
    var font: PlatformFont {
        let weight: PlatformFont.Weight
        switch fontWeight {
            case .ultraLight: weight = .ultraLight
            case .thin: weight = .thin
            case .light: weight = .light
            case .regular: weight = .regular
            case .medium: weight = .medium
            case .semibold: weight = .semibold
            case .bold: weight = .bold
            case .heavy: weight = .heavy
            case .black: weight = .black
        }

        return PlatformFont.systemFont(ofSize: fontSize, weight: weight)
    }
}
