//
//  ProjectManager.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import Foundation

    // MARK: - Project Import/Export

extension ProjectManager {

        /// Export project as ZIP (including media)
    func exportProjectBundle(project: Project, to url: URL, includeMedia: Bool = true) async throws {
            // Create temporary directory
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

            // Save project file
        let projectFile = tempDir.appendingPathComponent("project.\(Self.projectExtension)")
        try save(project: project, to: projectFile)

            // Copy media files
        if includeMedia {
            let mediaDir = tempDir.appendingPathComponent("media")
            try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

            for track in project.tracks {
                for clip in track.clips {
                    guard let sourceURL = clip.sourceURL else { return }
                    let destURL = mediaDir.appendingPathComponent(sourceURL.lastPathComponent)
                    if !FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.copyItem(at: sourceURL, to: destURL)
                    }
                }
            }
        }

            // Compress
        try FileManager.default.zipItem(at: tempDir, to: url)
    }

        /// Export project bundle
    func importProjectBundle(from url: URL) async throws -> Project {
            // Extract to temporary directory
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.unzipItem(at: url, to: tempDir)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

            // Find project file
        let projectFile = tempDir.appendingPathComponent("project.\(Self.projectExtension)")

        guard FileManager.default.fileExists(atPath: projectFile.path) else {
            throw ProjectError.invalidProjectBundle
        }

            // Copy media files to user directory
        let mediaDir = tempDir.appendingPathComponent("media")
        let destMediaDir = Self.projectsDirectory.appendingPathComponent("Media")

        if FileManager.default.fileExists(atPath: mediaDir.path) {
            if !FileManager.default.fileExists(atPath: destMediaDir.path) {
                try FileManager.default.createDirectory(at: destMediaDir, withIntermediateDirectories: true)
            }

            let mediaFiles = try FileManager.default.contentsOfDirectory(at: mediaDir, includingPropertiesForKeys: nil)
            for file in mediaFiles {
                let destFile = destMediaDir.appendingPathComponent(file.lastPathComponent)
                if !FileManager.default.fileExists(atPath: destFile.path) {
                    try FileManager.default.copyItem(at: file, to: destFile)
                }
            }
        }

            // Load project
        return try await load(from: projectFile)
    }
}

