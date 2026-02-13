//
//  FileManager.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation
import SwiftUI
    // MARK: - FileManager Extension

extension FileManager {
    func zipItem(at sourceURL: URL, to destURL: URL) throws {
        #if os(macOS)
        // Use system zip command (Process is macOS-only).
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", destURL.path, "."]
        process.currentDirectoryURL = sourceURL

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ProjectError.saveFailed
        }
        #else
        throw ProjectError.saveFailed
        #endif
    }

    func unzipItem(at sourceURL: URL, to destURL: URL) throws {
        #if os(macOS)
        try createDirectory(at: destURL, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", sourceURL.path, "-d", destURL.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ProjectError.loadFailed
        }
        #else
        throw ProjectError.loadFailed
        #endif
    }
}
