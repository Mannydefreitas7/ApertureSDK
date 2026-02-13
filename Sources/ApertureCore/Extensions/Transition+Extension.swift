//
//  Transition+Extension.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import AVFoundation

extension Transition {

    public enum TransitionType: String {
        case none
        case crossDissolve
        case fade
        case slideLeft
        case slideRight
        case slideUp
        case slideDown
        case wipeLeft
        case wipeRight
        case wipeUp
        case wipeDown
        case zoom
        case blur
        case dissolve

        public var displayName: String {
            switch self {
                case .none: return "None"
                case .crossDissolve: return "Cross Dissolve"
                case .fade: return "Fade"
                case .slideLeft: return "Slide Left"
                case .slideRight: return "Slide Right"
                case .slideUp: return "Slide Up"
                case .slideDown: return "Slide Down"
                case .wipeLeft: return "Wipe Left"
                case .wipeRight: return "Wipe Right"
                case .wipeUp: return "Wipe Up"
                case .wipeDown: return "Wipe Down"
                case .zoom: return "Zoom"
                case .blur: return "Blur"
                case .dissolve: return "Dissolve"
            }
        }

        public var icon: String {
            switch self {
                case .none: return "xmark"
                case .crossDissolve, .dissolve: return "square.on.square"
                case .fade: return "circle.lefthalf.filled"
                case .wipeLeft: return "arrow.left.square"
                case .wipeRight: return "arrow.right.square"
                case .wipeUp: return "arrow.up.square"
                case .wipeDown: return "arrow.down.square"
                case .slideLeft: return "rectangle.lefthalf.inset.filled.arrow.left"
                case .slideRight: return "rectangle.righthalf.inset.filled.arrow.right"
                case .slideUp: return "arrow.up.square"
                case .slideDown: return "arrow.down.square"
                case .zoom: return "arrow.up.left.and.arrow.down.right"
                case .blur: return "aqi.medium"
            }
        }
    }


}
