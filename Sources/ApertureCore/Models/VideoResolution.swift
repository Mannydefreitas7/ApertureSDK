//
//  VideoResolution.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import Foundation

enum VideoResolution: String, Codable, CaseIterable {
    case hd720p = "720p"
    case hd1080p = "1080p"
    case uhd4k = "4K"
    case vertical1080x1920 = "1080x1920"  // 竖屏

    var width: Int {
        switch self {
            case .hd720p: return 1280
            case .hd1080p: return 1920
            case .uhd4k: return 3840
            case .vertical1080x1920: return 1080
        }
    }

    var height: Int {
        switch self {
            case .hd720p: return 720
            case .hd1080p: return 1080
            case .uhd4k: return 2160
            case .vertical1080x1920: return 1920
        }
    }

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    var displayName: String {
        switch self {
            case .hd720p: return "720p (1280×720)"
            case .hd1080p: return "1080p (1920×1080)"
            case .uhd4k: return "4K (3840×2160)"
            case .vertical1080x1920: return "竖屏 (1080×1920)"
        }
    }
}
