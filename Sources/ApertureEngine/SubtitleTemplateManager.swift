//
//  SubtitleTemplateManager.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import SwiftUI


class SubtitleTemplateManager: ObservableObject {
    static let shared = SubtitleTemplateManager()

    @Published var templates: [SubtitleTemplate] = []
    @Published var categories = ["Basic", "Social", "Vlog", "Cinema", "News", "Entertainment", "Tutorial"]

    private init() {
        loadBuiltInTemplates()
    }

    private func loadBuiltInTemplates() {
        templates = [
            SubtitleTemplate(
                name: "Clean White Text",
                category: "Basic",
                style: TextStyle(fontName: "PingFang SC", fontSize: 32, textColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 1)),
                animation: .fadeIn
            ),
            SubtitleTemplate(
                name: "Yellow Outline",
                category: "Basic",
                style: TextStyle(fontName: "PingFang SC", fontSize: 36, textColor: CodableColor(red: 1, green: 0.9, blue: 0, alpha: 1), strokeColor: CodableColor(red: 0, green: 0, blue: 0, alpha: 1), strokeWidth: 2),
                animation: .fadeIn
            ),
            SubtitleTemplate(
                name: "Social Media Trending",
                category: "Social",
                style: TextStyle(fontName: "PingFang SC", fontSize: 40, textColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 1), backgroundColor: CodableColor(red: 0, green: 0, blue: 0, alpha: 0.7)),
                animation: .pop
            ),
            SubtitleTemplate(
                name: "Movie Subtitle",
                category: "Cinema",
                style: TextStyle(fontName: "STSong", fontSize: 28, textColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 1)),
                animation: .fadeIn
            ),
            SubtitleTemplate(
                name: "News Title",
                category: "News",
                style: TextStyle(fontName: "PingFang SC", fontSize: 48, textColor: CodableColor(red: 1, green: 0, blue: 0, alpha: 1), backgroundColor: CodableColor(red: 1, green: 1, blue: 1, alpha: 0.9)),
                animation: .slideFromBottom
            ),
        ]
    }

    func filterByCategory(_ category: String) -> [SubtitleTemplate] {
        if category == "All" {
            return templates
        }
        return templates.filter { $0.category == category }
    }
}
