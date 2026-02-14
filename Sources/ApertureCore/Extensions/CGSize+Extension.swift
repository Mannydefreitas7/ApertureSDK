//
//  CGSize+Extension.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import Foundation
import CoreGraphics

extension CGSize {

    // MARK: - Canvas Sizes
    public typealias CanvasSize = CGSize
    /// hd720p - width: 1280, height: 720
    public static var hd720p: Self { .init(width: 1280, height: 720) }
        /// hd1080p - width: 1920, height: 1080
    public static var hd1080p: Self { .init(width: 1920, height: 1080) }
        /// hd4K - width: 3840, height: 2160
    public static var hd4K: Self { .init(width: 3840, height: 2160) }
        /// square1080 - width: 1080, height: 1080
    public static var square1080 : Self { .init(width: 1080, height: 1080) }
        /// portrait1080x1920 - width: 1080, height: 1920
    public static var portrait1080x1920: Self { .init(width: 1080, height: 1920) }

        /// Aspect ratio (width / height)
    public var aspectRatio: Double {
        guard height > 0 else { return 0 }
        return width / height
    }

}
