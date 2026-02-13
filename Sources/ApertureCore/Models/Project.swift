//
//  Project.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation

    // MARK: - Serializable Project Models

    /// Serializable project data
    /// Represents a video editing project - serializable and AVFoundation-independent
public struct Project: Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var canvasSize: CanvasSize
    public var fps: Double
    public var audioSampleRate: Double
    public var tracks: [Track]
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        canvasSize: CanvasSize = .hd1080p,
        fps: Double = 30,
        audioSampleRate: Double = 44100,
        tracks: [Track] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.canvasSize = canvasSize
        self.fps = fps
        self.audioSampleRate = audioSampleRate
        self.tracks = tracks
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }  
}


    // MARK: - Project Templates

    /// Project template
struct ProjectTemplate: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var settings: ProjectSettings
    var icon: String
}

struct ProjectSettings: Codable {
    var resolution: VideoResolution
    var frameRate: Double
    var colorSpace: String

    init(
        resolution: VideoResolution = .hd1080p,
        frameRate: Double = 30.0,
        colorSpace: String = "Rec.709 SDR"
    ) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.colorSpace = colorSpace
    }
}
