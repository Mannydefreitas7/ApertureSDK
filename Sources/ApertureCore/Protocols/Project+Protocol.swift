//
//  Project+Protocol.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation

public protocol ProjectProtocol: Identifiable {

    public var id: UUID
    public var name: String
    public var canvasSize: CanvasSize
    public var fps: Double
    public var audioSampleRate: Double
    public var tracks: [Track]
    public var createdAt: Date
    public var modifiedAt: Date
    public var resolution: VideoResolution
    public var frameRate: Double
    public var colorSpace: String

}
