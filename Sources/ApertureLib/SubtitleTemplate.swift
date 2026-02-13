//
//  SubtitleTemplate.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//
import Foundation

struct SubtitleTemplate: Identifiable {
    let id: UUID
    var name: String
    var category: String
    var style: TextStyle
    var animation: TextAnimation
    var previewImage: String?

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        style: TextStyle,
        animation: TextAnimation,
        previewImage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.style = style
        self.animation = animation
        self.previewImage = previewImage
    }
}
