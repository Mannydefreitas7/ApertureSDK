//
//  Project+Error.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import Foundation

    /// Project errors
enum ProjectError: LocalizedError {
    case invalidProjectBundle
    case mediaNotFound
    case saveFailed
    case loadFailed

    var errorDescription: String? {
        switch self {
            case .invalidProjectBundle: return "Invalid project bundle"
            case .mediaNotFound: return "Media file not found"
            case .saveFailed: return "Save failed"
            case .loadFailed: return "Load failed"
        }
    }
}
