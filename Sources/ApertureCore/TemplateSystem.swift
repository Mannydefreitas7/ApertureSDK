import Foundation
import AVFoundation
import SwiftUI
#if canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
#endif
#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
#endif

// MARK: - Filter Presets

struct FilterPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var filterName: String
    var parameters: [String: Double]

    init(id: UUID = UUID(), name: String, filterName: String, parameters: [String: Double] = [:]) {
        self.id = id
        self.name = name
        self.filterName = filterName
        self.parameters = parameters
    }
}

// MARK: - Video Templates

struct VideoTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: TemplateCategory
    var description: String
    var duration: Double
    var aspectRatio: AspectRatio
    var placeholders: [TemplatePlaceholder]
    var tracks: [TemplateTrack]
    var transitions: [TemplateTransition]
    var filters: [FilterPreset]
    var music: TemplateMusic?
    var thumbnailURL: URL?
    var previewURL: URL?
    var tags: [String]
    var isPremium: Bool
    var author: String?
    var downloads: Int

    init(
        id: UUID = UUID(),
        name: String,
        category: TemplateCategory,
        description: String = "",
        duration: Double = 15,
        aspectRatio: AspectRatio = .ratio16x9,
        placeholders: [TemplatePlaceholder] = [],
        tracks: [TemplateTrack] = [],
        transitions: [TemplateTransition] = [],
        filters: [FilterPreset] = [],
        music: TemplateMusic? = nil,
        thumbnailURL: URL? = nil,
        previewURL: URL? = nil,
        tags: [String] = [],
        isPremium: Bool = false,
        author: String? = nil,
        downloads: Int = 0
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.duration = duration
        self.aspectRatio = aspectRatio
        self.placeholders = placeholders
        self.tracks = tracks
        self.transitions = transitions
        self.filters = filters
        self.music = music
        self.thumbnailURL = thumbnailURL
        self.previewURL = previewURL
        self.tags = tags
        self.isPremium = isPremium
        self.author = author
        self.downloads = downloads
    }

    enum AspectRatio: String, Codable, CaseIterable {
        case ratio16x9 = "16:9"
        case ratio9x16 = "9:16"
        case ratio1x1 = "1:1"
        case ratio4x3 = "4:3"
        case ratio21x9 = "21:9"

        var size: CGSize {
            switch self {
            case .ratio16x9: return CGSize(width: 1920, height: 1080)
            case .ratio9x16: return CGSize(width: 1080, height: 1920)
            case .ratio1x1: return CGSize(width: 1080, height: 1080)
            case .ratio4x3: return CGSize(width: 1440, height: 1080)
            case .ratio21x9: return CGSize(width: 2560, height: 1080)
            }
        }
    }
}


struct TemplatePlaceholder: Identifiable, Codable {
    let id: UUID
    var type: PlaceholderType
    var label: String
    var position: CGRect  // Normalized coordinates
    var startTime: Double
    var duration: Double
	#if os(iOS)
    var animation: TextAnimation?
	#endif
    var required: Bool



    init(
        id: UUID = UUID(),
        type: PlaceholderType,
        label: String,
        position: CGRect,
        startTime: Double = 0,
        duration: Double = 3,
        animation: TextAnimation? = nil,
        required: Bool = true
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.position = position
        self.startTime = startTime
        self.duration = duration
        self.animation = animation
        self.required = required
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case label
        case positionX
        case positionY
        case positionWidth
        case positionHeight
        case startTime
        case duration
        case animation
        case required
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .positionX)
        let y = try container.decode(Double.self, forKey: .positionY)
        let width = try container.decode(Double.self, forKey: .positionWidth)
        let height = try container.decode(Double.self, forKey: .positionHeight)

        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(PlaceholderType.self, forKey: .type)
        label = try container.decode(String.self, forKey: .label)
        position = CGRect(x: x, y: y, width: width, height: height)
        startTime = try container.decode(Double.self, forKey: .startTime)
        duration = try container.decode(Double.self, forKey: .duration)
        animation = try container.decodeIfPresent(TextAnimation.self, forKey: .animation)
        required = try container.decode(Bool.self, forKey: .required)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(label, forKey: .label)
        try container.encode(Double(position.origin.x), forKey: .positionX)
        try container.encode(Double(position.origin.y), forKey: .positionY)
        try container.encode(Double(position.size.width), forKey: .positionWidth)
        try container.encode(Double(position.size.height), forKey: .positionHeight)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(animation, forKey: .animation)
        try container.encode(required, forKey: .required)
    }
}



struct TemplateTrack: Codable {
    var type: Track.TrackType
    var clips: [TemplateClip]
}

struct TemplateClip: Codable {
    var placeholderId: UUID?
    var assetURL: URL?  // Built-in assets
    var startTime: Double
    var duration: Double
    var effects: [String]
}

struct TemplateTransition: Codable {
    var type: Transition.TransitionType
    var duration: Double
    var position: Double  // Position on timeline
}

struct TemplateMusic: Codable {
    var name: String
    var url: URL?
    var volume: Float
    var fadeIn: Double
    var fadeOut: Double
}

// MARK: - Template Manager

actor TemplateManager {
    static let shared = TemplateManager()

    var templates: [VideoTemplate] = []
    var featuredTemplates: [VideoTemplate] = []
    var recentTemplates: [VideoTemplate] = []
   var favoriteTemplateIds: Set<UUID> = []
    var isLoading = false
    var searchQuery = ""

    private init() {
        Task {  await loadBuiltInTemplates() }
    }

    private func loadBuiltInTemplates() async {
        templates = [
            // Intro template
            VideoTemplate(
                name: "Dynamic Intro",
                category: .intro,
                description: "Energetic intro animation",
                duration: 5,
                placeholders: [
                    TemplatePlaceholder(type: .text, label: "Title", position: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.2)),
                    TemplatePlaceholder(type: .logo, label: "Logo", position: CGRect(x: 0.35, y: 0.65, width: 0.3, height: 0.2))
                ],
                tags: ["Intro", "Dynamic", "Modern"]
            ),

            // Outro template
            VideoTemplate(
                name: "Clean Outro",
                category: .outro,
                description: "Simple ending card",
                duration: 5,
                placeholders: [
                    TemplatePlaceholder(type: .text, label: "Thanks for Watching", position: CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.15)),
                    TemplatePlaceholder(type: .text, label: "Subscribe", position: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1)),
                    TemplatePlaceholder(type: .logo, label: "Logo", position: CGRect(x: 0.4, y: 0.7, width: 0.2, height: 0.15))
                ],
                tags: ["Outro", "Clean", "Subscribe"]
            ),

            // Vlog template
            VideoTemplate(
                name: "Daily Vlog",
                category: .vlog,
                description: "Perfect for daily life vlogs",
                duration: 30,
                aspectRatio: .ratio9x16,
                placeholders: [
                    TemplatePlaceholder(type: .video, label: "Video 1", position: CGRect(x: 0, y: 0, width: 1, height: 0.5), duration: 5),
                    TemplatePlaceholder(type: .video, label: "Video 2", position: CGRect(x: 0, y: 0, width: 1, height: 0.5), startTime: 5, duration: 5),
                    TemplatePlaceholder(type: .video, label: "Video 3", position: CGRect(x: 0, y: 0, width: 1, height: 0.5), startTime: 10, duration: 5),
                    TemplatePlaceholder(type: .text, label: "Date", position: CGRect(x: 0.05, y: 0.85, width: 0.3, height: 0.05))
                ],
                tags: ["Vlog", "Daily", "Portrait"]
            ),

            // Travel template
            VideoTemplate(
                name: "Travel Memories",
                category: .travel,
                description: "Capture beautiful moments from your journey",
                duration: 60,
                placeholders: [
                    TemplatePlaceholder(type: .text, label: "Destination", position: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.2)),
                    TemplatePlaceholder(type: .image, label: "Cover", position: CGRect(x: 0, y: 0, width: 1, height: 1), duration: 3),
                    TemplatePlaceholder(type: .video, label: "Highlights", position: CGRect(x: 0, y: 0, width: 1, height: 1), startTime: 3)
                ],
                tags: ["Travel", "Scenic", "Memories"]
            ),

            // Holiday template
            VideoTemplate(
                name: "New Year Wishes",
                category: .newYear,
                description: "New Year greeting card template",
                duration: 15,
                placeholders: [
                    TemplatePlaceholder(type: .text, label: "Happy New Year", position: CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.2)),
                    TemplatePlaceholder(type: .text, label: "Year", position: CGRect(x: 0.3, y: 0.5, width: 0.4, height: 0.15)),
                    TemplatePlaceholder(type: .image, label: "Photo", position: CGRect(x: 0.25, y: 0.65, width: 0.5, height: 0.25))
                ],
                tags: ["New Year", "Wishes", "Holiday"]
            ),

            // E-commerce template
            VideoTemplate(
                name: "Product Showcase",
                category: .ecommerce,
                description: "Product promotional video template",
                duration: 15,
                aspectRatio: .ratio1x1,
                placeholders: [
                    TemplatePlaceholder(type: .image, label: "Product Image", position: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.6)),
                    TemplatePlaceholder(type: .text, label: "Product Name", position: CGRect(x: 0.1, y: 0.72, width: 0.8, height: 0.1)),
                    TemplatePlaceholder(type: .text, label: "Price", position: CGRect(x: 0.1, y: 0.84, width: 0.4, height: 0.08)),
                    TemplatePlaceholder(type: .logo, label: "Store Logo", position: CGRect(x: 0.7, y: 0.84, width: 0.2, height: 0.1))
                ],
                tags: ["E-commerce", "Product", "Promotion"]
            ),

            // Wedding template
            VideoTemplate(
                name: "Romantic Wedding",
                category: .wedding,
                description: "Capture life's most beautiful moments",
                duration: 120,
                placeholders: [
                    TemplatePlaceholder(type: .text, label: "Couple Names", position: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.15)),
                    TemplatePlaceholder(type: .text, label: "Wedding Date", position: CGRect(x: 0.2, y: 0.55, width: 0.6, height: 0.08)),
                    TemplatePlaceholder(type: .video, label: "Wedding Video", position: CGRect(x: 0, y: 0, width: 1, height: 1))
                ],
                tags: ["Wedding", "Romantic", "Love"],
                isPremium: true
            ),
        ]

        featuredTemplates = Array(templates.prefix(5))
    }

    // Search templates
    func search(_ query: String) -> [VideoTemplate] {
        guard !query.isEmpty else { return templates }

        return templates.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    // Filter by category
    func filterByCategory(_ category: TemplateCategory) -> [VideoTemplate] {
        templates.filter { $0.category == category }
    }

    // Add/remove from favorites
    func toggleFavorite(_ template: VideoTemplate) {
        if favoriteTemplateIds.contains(template.id) {
            favoriteTemplateIds.remove(template.id)
        } else {
            favoriteTemplateIds.insert(template.id)
        }
    }

    // Get favorite templates
    var favoriteTemplates: [VideoTemplate] {
        templates.filter { favoriteTemplateIds.contains($0.id) }
    }

    // Apply template
    func applyTemplate(_ template: VideoTemplate, with assets: [UUID: URL]) async throws -> Project {
        var project = Project(name: "Created from Template - \(template.name)")

        // Set resolution based on template aspect ratio
        switch template.aspectRatio {
        case .ratio16x9:
            project.settings.resolution = .hd1080p
        case .ratio9x16:
            project.settings.resolution = .vertical1080x1920
        default:
            project.settings.resolution = .hd1080p
        }

        return project
    }

    // Save custom template
    func saveAsTemplate(_ project: Project, name: String, category: TemplateCategory) -> VideoTemplate {
        let template = VideoTemplate(
            name: name,
            category: category,
            description: "",
            duration: CMTimeGetSeconds(project.duration),
            author: "User"
        )

        templates.append(template)
        return template
    }
}
