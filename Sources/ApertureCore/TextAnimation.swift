//
//  TextAnimation.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import Foundation
    /// Text animation
public enum TextAnimation: String, CaseIterable, Codable {
    case none = "None"
    case fadeIn = "Fade In"
    case fadeOut = "Fade Out"
    case fadeInOut = "Fade In/Out"
    case slideUp = "Slide Up"
    case slideDown = "Slide Down"
    case slideLeft = "Slide Left"
    case slideRight = "Slide Right"
    case slideFromBottom = "Slide From Bottom"
    case typewriter = "Typewriter"
    case scale = "Scale"
    case bounce = "Bounce"
    case pop = "Pop"

    public var icon: String {
        switch self {
            case .none: return "xmark"
            case .fadeIn: return "circle.righthalf.filled"
            case .fadeOut: return "circle.lefthalf.filled"
            case .fadeInOut: return "circle.fill"
            case .slideUp: return "arrow.up"
            case .slideDown: return "arrow.down"
            case .slideLeft: return "arrow.left"
            case .slideRight: return "arrow.right"
            case .slideFromBottom: return "arrow.up.square"
            case .typewriter: return "keyboard"
            case .scale: return "arrow.up.left.and.arrow.down.right"
            case .bounce: return "arrow.up.and.down"
            case .pop: return "sparkles"
        }
    }
}
