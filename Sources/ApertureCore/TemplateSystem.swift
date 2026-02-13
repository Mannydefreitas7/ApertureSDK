import Foundation
import AVFoundation
import SwiftUI

// MARK: - 滤镜预设

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

// MARK: - 视频模板

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

enum TemplateCategory: String, Codable, CaseIterable {
    case intro = "开场"
    case outro = "片尾"
    case vlog = "Vlog"
    case travel = "旅行"
    case food = "美食"
    case fitness = "健身"
    case wedding = "婚礼"
    case birthday = "生日"
    case holiday = "节日"
    case christmas = "圣诞"
    case newYear = "新年"
    case valentines = "情人节"
    case ecommerce = "电商"
    case education = "教育"
    case corporate = "商务"
    case social = "社交"
    case gaming = "游戏"
    case music = "音乐"
    case sports = "运动"
    case news = "新闻"
    case slideshow = "相册"
    case promo = "宣传"
    case custom = "自定义"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .intro: return "play.rectangle"
        case .outro: return "stop.rectangle"
        case .vlog: return "video"
        case .travel: return "airplane"
        case .food: return "fork.knife"
        case .fitness: return "figure.run"
        case .wedding: return "heart.fill"
        case .birthday: return "gift"
        case .holiday, .christmas, .newYear, .valentines: return "sparkles"
        case .ecommerce: return "cart"
        case .education: return "book"
        case .corporate: return "building.2"
        case .social: return "person.2"
        case .gaming: return "gamecontroller"
        case .music: return "music.note"
        case .sports: return "sportscourt"
        case .news: return "newspaper"
        case .slideshow: return "photo.on.rectangle"
        case .promo: return "megaphone"
        case .custom: return "square.grid.2x2"
        }
    }
}

struct TemplatePlaceholder: Identifiable, Codable {
    let id: UUID
    var type: PlaceholderType
    var label: String
    var position: CGRect  // 归一化坐标
    var startTime: Double
    var duration: Double
    var animation: TextAnimation?
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
}

enum PlaceholderType: String, Codable {
    case video
    case image
    case text
    case logo
}

struct TemplateTrack: Codable {
    var type: TrackType
    var clips: [TemplateClip]
}

struct TemplateClip: Codable {
    var placeholderId: UUID?
    var assetURL: URL?  // 内置资源
    var startTime: Double
    var duration: Double
    var effects: [String]
}

struct TemplateTransition: Codable {
    var type: TransitionType
    var duration: Double
    var position: Double  // 在时间线上的位置
}

struct TemplateMusic: Codable {
    var name: String
    var url: URL?
    var volume: Float
    var fadeIn: Double
    var fadeOut: Double
}

// MARK: - 模板管理器

class TemplateManager: ObservableObject {
    static let shared = TemplateManager()

    @Published var templates: [VideoTemplate] = []
    @Published var featuredTemplates: [VideoTemplate] = []
    @Published var recentTemplates: [VideoTemplate] = []
    @Published var favoriteTemplateIds: Set<UUID> = []
    @Published var isLoading = false
    @Published var searchQuery = ""

    private init() {
        loadBuiltInTemplates()
    }

    private func loadBuiltInTemplates() {
        templates = [
            // 开场模板
            VideoTemplate(
                name: "动感开场",
                category: .intro,
                description: "充满活力的开场动画",
                duration: 5,
                placeholders: [
                    TemplatePlaceholder(type: .text, label: "标题", position: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.2)),
                    TemplatePlaceholder(type: .logo, label: "Logo", position: CGRect(x: 0.35, y: 0.65, width: 0.3, height: 0.2))
                ],
                tags: ["开场", "动感", "现代"]
            ),

            // 片尾模板
            VideoTemplate(
                name: "简洁片尾",
                category: .outro,
                description: "简洁的结尾卡片",
                duration: 5,
                placeholders: [
                    TemplatePlaceholder(type: .text, label: "感谢观看", position: CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.15)),
                    TemplatePlaceholder(type: .text, label: "订阅频道", position: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1)),
                    TemplatePlaceholder(type: .logo, label: "Logo", position: CGRect(x: 0.4, y: 0.7, width: 0.2, height: 0.15))
                ],
                tags: ["片尾", "简洁", "订阅"]
            ),

            // Vlog模板
            VideoTemplate(
                name: "日常Vlog",
                category: .vlog,
                description: "适合日常记录的Vlog模板",
                duration: 30,
                aspectRatio: .ratio9x16,
                placeholders: [
                    TemplatePlaceholder(type: .video, label: "视频1", position: CGRect(x: 0, y: 0, width: 1, height: 0.5), duration: 5),
                    TemplatePlaceholder(type: .video, label: "视频2", position: CGRect(x: 0, y: 0, width: 1, height: 0.5), startTime: 5, duration: 5),
                    TemplatePlaceholder(type: .video, label: "视频3", position: CGRect(x: 0, y: 0, width: 1, height: 0.5), startTime: 10, duration: 5),
                    TemplatePlaceholder(type: .text, label: "日期", position: CGRect(x: 0.05, y: 0.85, width: 0.3, height: 0.05))
                ],
                tags: ["Vlog", "日常", "竖屏"]
            ),

            // 旅行模板
            VideoTemplate(
                name: "旅行记忆",
                category: .travel,
                description: "记录旅途中的美好时刻",
                duration: 60,
                placeholders: [
                    TemplatePlaceholder(type: .text, label: "目的地", position: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.2)),
                    TemplatePlaceholder(type: .image, label: "封面", position: CGRect(x: 0, y: 0, width: 1, height: 1), duration: 3),
                    TemplatePlaceholder(type: .video, label: "精彩片段", position: CGRect(x: 0, y: 0, width: 1, height: 1), startTime: 3)
                ],
                tags: ["旅行", "风景", "记忆"]
            ),

            // 节日模板
            VideoTemplate(
                name: "新年祝福",
                category: .newYear,
                description: "新年贺卡模板",
                duration: 15,
                placeholders: [
                    TemplatePlaceholder(type: .text, label: "新年快乐", position: CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.2)),
                    TemplatePlaceholder(type: .text, label: "年份", position: CGRect(x: 0.3, y: 0.5, width: 0.4, height: 0.15)),
                    TemplatePlaceholder(type: .image, label: "照片", position: CGRect(x: 0.25, y: 0.65, width: 0.5, height: 0.25))
                ],
                tags: ["新年", "祝福", "节日"]
            ),

            // 电商模板
            VideoTemplate(
                name: "产品展示",
                category: .ecommerce,
                description: "产品宣传视频模板",
                duration: 15,
                aspectRatio: .ratio1x1,
                placeholders: [
                    TemplatePlaceholder(type: .image, label: "产品图", position: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.6)),
                    TemplatePlaceholder(type: .text, label: "产品名称", position: CGRect(x: 0.1, y: 0.72, width: 0.8, height: 0.1)),
                    TemplatePlaceholder(type: .text, label: "价格", position: CGRect(x: 0.1, y: 0.84, width: 0.4, height: 0.08)),
                    TemplatePlaceholder(type: .logo, label: "店铺Logo", position: CGRect(x: 0.7, y: 0.84, width: 0.2, height: 0.1))
                ],
                tags: ["电商", "产品", "促销"]
            ),

            // 婚礼模板
            VideoTemplate(
                name: "浪漫婚礼",
                category: .wedding,
                description: "记录人生最美好的时刻",
                duration: 120,
                placeholders: [
                    TemplatePlaceholder(type: .text, label: "新人姓名", position: CGRect(x: 0.1, y: 0.4, width: 0.8, height: 0.15)),
                    TemplatePlaceholder(type: .text, label: "婚礼日期", position: CGRect(x: 0.2, y: 0.55, width: 0.6, height: 0.08)),
                    TemplatePlaceholder(type: .video, label: "婚礼视频", position: CGRect(x: 0, y: 0, width: 1, height: 1))
                ],
                tags: ["婚礼", "浪漫", "爱情"],
                isPremium: true
            ),
        ]

        featuredTemplates = Array(templates.prefix(5))
    }

    // 搜索模板
    func search(_ query: String) -> [VideoTemplate] {
        guard !query.isEmpty else { return templates }

        return templates.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    // 按分类筛选
    func filterByCategory(_ category: TemplateCategory) -> [VideoTemplate] {
        templates.filter { $0.category == category }
    }

    // 收藏/取消收藏
    func toggleFavorite(_ template: VideoTemplate) {
        if favoriteTemplateIds.contains(template.id) {
            favoriteTemplateIds.remove(template.id)
        } else {
            favoriteTemplateIds.insert(template.id)
        }
    }

    // 获取收藏的模板
    var favoriteTemplates: [VideoTemplate] {
        templates.filter { favoriteTemplateIds.contains($0.id) }
    }

    // 应用模板
    func applyTemplate(_ template: VideoTemplate, with assets: [UUID: URL]) async throws -> Project {
        var project = Project(name: "从模板创建 - \(template.name)")

        // 设置分辨率根据模板宽高比
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

    // 保存自定义模板
    func saveAsTemplate(_ project: Project, name: String, category: TemplateCategory) -> VideoTemplate {
        let template = VideoTemplate(
            name: name,
            category: category,
            description: "",
            duration: CMTimeGetSeconds(project.duration),
            author: "用户"
        )

        templates.append(template)
        return template
    }
}

// MARK: - Codable Color Helper

struct CodableColor: Codable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    #if os(iOS) || os(macOS)
    var color: NSColor? {
        #if os(iOS)
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        #else
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
        #endif
    }
    #endif
}
