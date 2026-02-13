//
//  MediaManagement.swift
//  VideoEditor
//
//  媒体管理系统 - 智能文件夹、标签、收藏、搜索、云素材库
//

import Foundation
import AVFoundation
import CoreImage
import Vision
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 媒体项目模型

/// 媒体类型
enum MediaType: String, Codable, CaseIterable {
    case video = "video"
    case audio = "audio"
    case image = "image"
    case gif = "gif"
    case livePhoto = "livePhoto"
    case document = "document"
    case project = "project"
    case template = "template"
    case effect = "effect"
    case music = "music"
    case soundEffect = "soundEffect"
    case font = "font"
    case lut = "lut"
    case preset = "preset"

    var icon: String {
        switch self {
        case .video: return "video.fill"
        case .audio: return "waveform"
        case .image: return "photo.fill"
        case .gif: return "photo.on.rectangle"
        case .livePhoto: return "livephoto"
        case .document: return "doc.fill"
        case .project: return "film.fill"
        case .template: return "square.grid.2x2.fill"
        case .effect: return "sparkles"
        case .music: return "music.note"
        case .soundEffect: return "speaker.wave.2.fill"
        case .font: return "textformat"
        case .lut: return "cube.fill"
        case .preset: return "slider.horizontal.3"
        }
    }

    var supportedExtensions: [String] {
        switch self {
        case .video: return ["mp4", "mov", "m4v", "avi", "mkv", "webm", "flv", "wmv", "3gp"]
        case .audio: return ["mp3", "wav", "aac", "m4a", "flac", "ogg", "wma", "aiff"]
        case .image: return ["jpg", "jpeg", "png", "heic", "heif", "tiff", "bmp", "webp", "raw"]
        case .gif: return ["gif"]
        case .livePhoto: return ["livp"]
        case .document: return ["pdf", "txt", "rtf", "doc", "docx"]
        case .project: return ["vep", "veproject"]
        case .template: return ["vet", "vetemplate"]
        case .effect: return ["vef", "veeffect"]
        case .music: return ["mp3", "wav", "aac", "m4a"]
        case .soundEffect: return ["mp3", "wav", "aac"]
        case .font: return ["ttf", "otf", "woff", "woff2"]
        case .lut: return ["cube", "3dl", "look"]
        case .preset: return ["vepre", "vepreset"]
        }
    }
}

/// 媒体元数据
struct MediaMetadata: Codable {
    var width: Int?
    var height: Int?
    var duration: Double?
    var frameRate: Double?
    var bitRate: Int?
    var codec: String?
    var colorSpace: String?
    var hasAlpha: Bool?
    var audioChannels: Int?
    var sampleRate: Int?
    var creationDate: Date?
    var modificationDate: Date?
    var location: MediaLocation?
    var camera: String?
    var lens: String?
    var iso: Int?
    var aperture: Double?
    var shutterSpeed: String?
    var focalLength: Double?
    var orientation: Int?
}

/// 媒体位置
struct MediaLocation: Codable {
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var address: String?
    var city: String?
    var country: String?
}

/// AI分析结果
struct AIAnalysisResult: Codable {
    var faces: [DetectedFace]
    var objects: [DetectedObject]
    var scenes: [DetectedScene]
    var text: [DetectedText]
    var colors: [DominantColor]
    var quality: MediaQuality
    var sentiment: String?
    var keywords: [String]
    var transcription: String?
}

struct DetectedFace: Codable {
    var id: String
    var bounds: CGRect
    var name: String?
    var confidence: Float
    var landmarks: [String: CGPoint]?
    var emotion: String?
    var age: Int?
    var gender: String?
}

struct DetectedObject: Codable {
    var id: String
    var label: String
    var confidence: Float
    var bounds: CGRect
    var category: String?
}

struct DetectedScene: Codable {
    var label: String
    var confidence: Float
    var category: String
}

struct DetectedText: Codable {
    var text: String
    var bounds: CGRect
    var confidence: Float
    var language: String?
}

struct DominantColor: Codable {
    var red: Float
    var green: Float
    var blue: Float
    var percentage: Float
    var name: String?
}

struct MediaQuality: Codable {
    var sharpness: Float
    var exposure: Float
    var contrast: Float
    var noise: Float
    var blur: Float
    var overall: Float
}

/// 媒体资源
class MediaAsset: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var name: String
    @Published var type: MediaType
    @Published var url: URL
    @Published var thumbnailURL: URL?
    @Published var proxyURL: URL?
    @Published var fileSize: Int64
    @Published var metadata: MediaMetadata
    @Published var aiAnalysis: AIAnalysisResult?
    @Published var tags: Set<String>
    @Published var rating: Int
    @Published var isFavorite: Bool
    @Published var color: String?
    @Published var notes: String
    @Published var usageCount: Int
    @Published var lastUsedDate: Date?
    @Published var importDate: Date
    @Published var isCloudItem: Bool
    @Published var cloudStatus: CloudItemStatus
    @Published var linkedProjects: [UUID]

    enum CodingKeys: String, CodingKey {
        case id, name, type, url, thumbnailURL, proxyURL, fileSize, metadata
        case aiAnalysis, tags, rating, isFavorite, color, notes, usageCount
        case lastUsedDate, importDate, isCloudItem, cloudStatus, linkedProjects
    }

    init(name: String, type: MediaType, url: URL) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.url = url
        self.fileSize = 0
        self.metadata = MediaMetadata()
        self.tags = []
        self.rating = 0
        self.isFavorite = false
        self.notes = ""
        self.usageCount = 0
        self.importDate = Date()
        self.isCloudItem = false
        self.cloudStatus = .local
        self.linkedProjects = []
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(MediaType.self, forKey: .type)
        url = try container.decode(URL.self, forKey: .url)
        thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        proxyURL = try container.decodeIfPresent(URL.self, forKey: .proxyURL)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
        metadata = try container.decode(MediaMetadata.self, forKey: .metadata)
        aiAnalysis = try container.decodeIfPresent(AIAnalysisResult.self, forKey: .aiAnalysis)
        tags = try container.decode(Set<String>.self, forKey: .tags)
        rating = try container.decode(Int.self, forKey: .rating)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        notes = try container.decode(String.self, forKey: .notes)
        usageCount = try container.decode(Int.self, forKey: .usageCount)
        lastUsedDate = try container.decodeIfPresent(Date.self, forKey: .lastUsedDate)
        importDate = try container.decode(Date.self, forKey: .importDate)
        isCloudItem = try container.decode(Bool.self, forKey: .isCloudItem)
        cloudStatus = try container.decode(CloudItemStatus.self, forKey: .cloudStatus)
        linkedProjects = try container.decode([UUID].self, forKey: .linkedProjects)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encodeIfPresent(proxyURL, forKey: .proxyURL)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(metadata, forKey: .metadata)
        try container.encodeIfPresent(aiAnalysis, forKey: .aiAnalysis)
        try container.encode(tags, forKey: .tags)
        try container.encode(rating, forKey: .rating)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encode(notes, forKey: .notes)
        try container.encode(usageCount, forKey: .usageCount)
        try container.encodeIfPresent(lastUsedDate, forKey: .lastUsedDate)
        try container.encode(importDate, forKey: .importDate)
        try container.encode(isCloudItem, forKey: .isCloudItem)
        try container.encode(cloudStatus, forKey: .cloudStatus)
        try container.encode(linkedProjects, forKey: .linkedProjects)
    }
}

/// 云端状态
enum CloudItemStatus: String, Codable {
    case local = "local"
    case uploading = "uploading"
    case uploaded = "uploaded"
    case downloading = "downloading"
    case synced = "synced"
    case error = "error"
    case cloudOnly = "cloudOnly"
}

// MARK: - 智能文件夹

/// 智能文件夹条件
struct SmartFolderCondition: Codable {
    var field: ConditionField
    var comparison: ConditionComparison
    var value: String
    var conjunction: ConditionConjunction

    enum ConditionField: String, Codable, CaseIterable {
        case name = "name"
        case type = "type"
        case tag = "tag"
        case rating = "rating"
        case favorite = "favorite"
        case date = "date"
        case duration = "duration"
        case resolution = "resolution"
        case fileSize = "fileSize"
        case color = "color"
        case face = "face"
        case object = "object"
        case scene = "scene"
        case location = "location"
        case camera = "camera"
        case keyword = "keyword"
        case usageCount = "usageCount"
    }

    enum ConditionComparison: String, Codable, CaseIterable {
        case equals = "equals"
        case notEquals = "notEquals"
        case contains = "contains"
        case notContains = "notContains"
        case startsWith = "startsWith"
        case endsWith = "endsWith"
        case greaterThan = "greaterThan"
        case lessThan = "lessThan"
        case between = "between"
        case isEmpty = "isEmpty"
        case isNotEmpty = "isNotEmpty"
    }

    enum ConditionConjunction: String, Codable {
        case and = "and"
        case or = "or"
    }
}

/// 智能文件夹
class SmartFolder: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var name: String
    @Published var icon: String
    @Published var color: String
    @Published var conditions: [SmartFolderCondition]
    @Published var matchAll: Bool
    @Published var sortBy: SortOption
    @Published var sortAscending: Bool
    @Published var limit: Int?
    @Published var isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, icon, color, conditions, matchAll, sortBy, sortAscending, limit, isEnabled
    }

    enum SortOption: String, Codable, CaseIterable {
        case name = "name"
        case date = "date"
        case duration = "duration"
        case fileSize = "fileSize"
        case rating = "rating"
        case usageCount = "usageCount"
        case type = "type"
    }

    init(name: String, conditions: [SmartFolderCondition] = []) {
        self.id = UUID()
        self.name = name
        self.icon = "folder.fill"
        self.color = "blue"
        self.conditions = conditions
        self.matchAll = true
        self.sortBy = .date
        self.sortAscending = false
        self.isEnabled = true
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(String.self, forKey: .color)
        conditions = try container.decode([SmartFolderCondition].self, forKey: .conditions)
        matchAll = try container.decode(Bool.self, forKey: .matchAll)
        sortBy = try container.decode(SortOption.self, forKey: .sortBy)
        sortAscending = try container.decode(Bool.self, forKey: .sortAscending)
        limit = try container.decodeIfPresent(Int.self, forKey: .limit)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(color, forKey: .color)
        try container.encode(conditions, forKey: .conditions)
        try container.encode(matchAll, forKey: .matchAll)
        try container.encode(sortBy, forKey: .sortBy)
        try container.encode(sortAscending, forKey: .sortAscending)
        try container.encodeIfPresent(limit, forKey: .limit)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    /// 匹配媒体项目
    func matches(_ item: MediaAsset) -> Bool {
        if conditions.isEmpty { return true }

        var results: [Bool] = []

        for condition in conditions {
            let matches = evaluateCondition(condition, for: item)
            results.append(matches)
        }

        if matchAll {
            return results.allSatisfy { $0 }
        } else {
            return results.contains { $0 }
        }
    }

    private func evaluateCondition(_ condition: SmartFolderCondition, for item: MediaAsset) -> Bool {
        switch condition.field {
        case .name:
            return compareString(item.name, condition.comparison, condition.value)
        case .type:
            return item.type.rawValue == condition.value
        case .tag:
            return item.tags.contains(condition.value)
        case .rating:
            return compareNumber(Double(item.rating), condition.comparison, Double(condition.value) ?? 0)
        case .favorite:
            return item.isFavorite == (condition.value == "true")
        case .date:
            if let date = parseDate(condition.value) {
                return compareDate(item.importDate, condition.comparison, date)
            }
            return false
        case .duration:
            if let duration = item.metadata.duration {
                return compareNumber(duration, condition.comparison, Double(condition.value) ?? 0)
            }
            return false
        case .resolution:
            if let width = item.metadata.width, let height = item.metadata.height {
                let resolution = "\(width)x\(height)"
                return compareString(resolution, condition.comparison, condition.value)
            }
            return false
        case .fileSize:
            return compareNumber(Double(item.fileSize), condition.comparison, Double(condition.value) ?? 0)
        case .color:
            return item.color == condition.value
        case .face:
            if let faces = item.aiAnalysis?.faces {
                return faces.contains { $0.name?.lowercased().contains(condition.value.lowercased()) ?? false }
            }
            return false
        case .object:
            if let objects = item.aiAnalysis?.objects {
                return objects.contains { $0.label.lowercased().contains(condition.value.lowercased()) }
            }
            return false
        case .scene:
            if let scenes = item.aiAnalysis?.scenes {
                return scenes.contains { $0.label.lowercased().contains(condition.value.lowercased()) }
            }
            return false
        case .location:
            if let location = item.metadata.location {
                let locationString = [location.city, location.country, location.address].compactMap { $0 }.joined(separator: " ")
                return compareString(locationString, condition.comparison, condition.value)
            }
            return false
        case .camera:
            if let camera = item.metadata.camera {
                return compareString(camera, condition.comparison, condition.value)
            }
            return false
        case .keyword:
            if let keywords = item.aiAnalysis?.keywords {
                return keywords.contains { $0.lowercased().contains(condition.value.lowercased()) }
            }
            return false
        case .usageCount:
            return compareNumber(Double(item.usageCount), condition.comparison, Double(condition.value) ?? 0)
        }
    }

    private func compareString(_ value: String, _ comparison: SmartFolderCondition.ConditionComparison, _ target: String) -> Bool {
        let lowercaseValue = value.lowercased()
        let lowercaseTarget = target.lowercased()

        switch comparison {
        case .equals:
            return lowercaseValue == lowercaseTarget
        case .notEquals:
            return lowercaseValue != lowercaseTarget
        case .contains:
            return lowercaseValue.contains(lowercaseTarget)
        case .notContains:
            return !lowercaseValue.contains(lowercaseTarget)
        case .startsWith:
            return lowercaseValue.hasPrefix(lowercaseTarget)
        case .endsWith:
            return lowercaseValue.hasSuffix(lowercaseTarget)
        case .isEmpty:
            return value.isEmpty
        case .isNotEmpty:
            return !value.isEmpty
        default:
            return false
        }
    }

    private func compareNumber(_ value: Double, _ comparison: SmartFolderCondition.ConditionComparison, _ target: Double) -> Bool {
        switch comparison {
        case .equals:
            return value == target
        case .notEquals:
            return value != target
        case .greaterThan:
            return value > target
        case .lessThan:
            return value < target
        default:
            return false
        }
    }

    private func compareDate(_ value: Date, _ comparison: SmartFolderCondition.ConditionComparison, _ target: Date) -> Bool {
        switch comparison {
        case .equals:
            return Calendar.current.isDate(value, inSameDayAs: target)
        case .greaterThan:
            return value > target
        case .lessThan:
            return value < target
        default:
            return false
        }
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

// MARK: - 标签系统

/// 标签
class MediaTag: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var name: String
    @Published var color: String
    @Published var icon: String?
    @Published var parent: UUID?
    @Published var children: [UUID]
    @Published var usageCount: Int
    @Published var createdDate: Date

    enum CodingKeys: String, CodingKey {
        case id, name, color, icon, parent, children, usageCount, createdDate
    }

    init(name: String, color: String = "gray") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.children = []
        self.usageCount = 0
        self.createdDate = Date()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(String.self, forKey: .color)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        parent = try container.decodeIfPresent(UUID.self, forKey: .parent)
        children = try container.decode([UUID].self, forKey: .children)
        usageCount = try container.decode(Int.self, forKey: .usageCount)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(parent, forKey: .parent)
        try container.encode(children, forKey: .children)
        try container.encode(usageCount, forKey: .usageCount)
        try container.encode(createdDate, forKey: .createdDate)
    }
}

/// 标签管理器
class TagManager: ObservableObject {
    static let shared = TagManager()

    @Published var tags: [MediaTag] = []
    @Published var recentTags: [MediaTag] = []
    @Published var suggestedTags: [String] = []

    private let maxRecentTags = 10

    init() {
        loadTags()
        createDefaultTags()
    }

    /// 创建标签
    func createTag(name: String, color: String = "gray", parent: UUID? = nil) -> MediaTag {
        let tag = MediaTag(name: name, color: color)
        tag.parent = parent

        if let parentId = parent, let parentTag = tags.first(where: { $0.id == parentId }) {
            parentTag.children.append(tag.id)
        }

        tags.append(tag)
        saveTags()
        return tag
    }

    /// 删除标签
    func deleteTag(_ tag: MediaTag) {
        // 删除子标签
        for childId in tag.children {
            if let childTag = tags.first(where: { $0.id == childId }) {
                deleteTag(childTag)
            }
        }

        // 从父标签移除
        if let parentId = tag.parent, let parentTag = tags.first(where: { $0.id == parentId }) {
            parentTag.children.removeAll { $0 == tag.id }
        }

        tags.removeAll { $0.id == tag.id }
        saveTags()
    }

    /// 重命名标签
    func renameTag(_ tag: MediaTag, to newName: String) {
        tag.name = newName
        saveTags()
    }

    /// 合并标签
    func mergeTags(_ sourceTags: [MediaTag], into targetTag: MediaTag) {
        for sourceTag in sourceTags where sourceTag.id != targetTag.id {
            targetTag.usageCount += sourceTag.usageCount
            deleteTag(sourceTag)
        }
        saveTags()
    }

    /// 获取根标签
    func getRootTags() -> [MediaTag] {
        return tags.filter { $0.parent == nil }
    }

    /// 获取子标签
    func getChildTags(of parent: MediaTag) -> [MediaTag] {
        return parent.children.compactMap { childId in
            tags.first { $0.id == childId }
        }
    }

    /// 搜索标签
    func searchTags(query: String) -> [MediaTag] {
        guard !query.isEmpty else { return tags }
        return tags.filter { $0.name.lowercased().contains(query.lowercased()) }
    }

    /// 更新最近使用
    func updateRecentTag(_ tag: MediaTag) {
        recentTags.removeAll { $0.id == tag.id }
        recentTags.insert(tag, at: 0)
        if recentTags.count > maxRecentTags {
            recentTags = Array(recentTags.prefix(maxRecentTags))
        }
        tag.usageCount += 1
        saveTags()
    }

    /// AI建议标签
    func suggestTags(for item: MediaAsset) -> [String] {
        var suggestions: [String] = []

        // 基于类型
        suggestions.append(item.type.rawValue)

        // 基于AI分析
        if let analysis = item.aiAnalysis {
            suggestions.append(contentsOf: analysis.keywords.prefix(5))
            suggestions.append(contentsOf: analysis.scenes.prefix(3).map { $0.label })
            suggestions.append(contentsOf: analysis.objects.prefix(3).map { $0.label })
        }

        // 基于元数据
        if let camera = item.metadata.camera {
            suggestions.append(camera)
        }
        if let location = item.metadata.location?.city {
            suggestions.append(location)
        }

        return Array(Set(suggestions))
    }

    private func createDefaultTags() {
        let defaultTags = [
            ("工作", "blue"),
            ("个人", "green"),
            ("旅行", "orange"),
            ("家庭", "pink"),
            ("活动", "purple"),
            ("项目", "yellow"),
            ("素材", "cyan"),
            ("完成", "gray")
        ]

        for (name, color) in defaultTags {
            if !tags.contains(where: { $0.name == name }) {
                _ = createTag(name: name, color: color)
            }
        }
    }

    private func loadTags() {
        // 从本地加载标签
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tagsURL = documentsURL.appendingPathComponent("media_tags.json")

        if let data = try? Data(contentsOf: tagsURL),
           let loadedTags = try? JSONDecoder().decode([MediaTag].self, from: data) {
            self.tags = loadedTags
        }
    }

    private func saveTags() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tagsURL = documentsURL.appendingPathComponent("media_tags.json")

        if let data = try? JSONEncoder().encode(tags) {
            try? data.write(to: tagsURL)
        }
    }
}

// MARK: - 媒体库管理器

/// 媒体库管理器
class MediaLibraryManager: ObservableObject {
    static let shared = MediaLibraryManager()

    @Published var items: [MediaAsset] = []
    @Published var smartFolders: [SmartFolder] = []
    @Published var collections: [MediaCollection] = []
    @Published var isLoading: Bool = false
    @Published var importProgress: Double = 0
    @Published var searchResults: [MediaAsset] = []
    @Published var currentFilter: MediaFilter?

    private var thumbnailCache: [UUID: CGImage] = [:]
    private var metadataQueue = DispatchQueue(label: "com.videoeditor.metadata", qos: .utility)
    private var analysisQueue = DispatchQueue(label: "com.videoeditor.analysis", qos: .background)

    init() {
        loadLibrary()
        createDefaultSmartFolders()
    }

    // MARK: - 导入功能

    /// 导入媒体文件
    func importMedia(from urls: [URL], completion: @escaping ([MediaAsset]) -> Void) {
        isLoading = true
        importProgress = 0

        var importedItems: [MediaAsset] = []
        let total = Double(urls.count)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for (index, url) in urls.enumerated() {
                if let item = self?.createMediaItem(from: url) {
                    importedItems.append(item)

                    DispatchQueue.main.async {
                        self?.items.append(item)
                        self?.importProgress = Double(index + 1) / total
                    }

                    // 后台生成缩略图和分析
                    self?.generateThumbnail(for: item)
                    self?.analyzeMedia(item)
                }
            }

            DispatchQueue.main.async {
                self?.isLoading = false
                self?.saveLibrary()
                completion(importedItems)
            }
        }
    }

    /// 创建媒体项目
    private func createMediaItem(from url: URL) -> MediaAsset? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let ext = url.pathExtension.lowercased()
        var mediaType: MediaType = .document

        for type in MediaType.allCases {
            if type.supportedExtensions.contains(ext) {
                mediaType = type
                break
            }
        }

        let item = MediaAsset(name: url.lastPathComponent, type: mediaType, url: url)

        // 获取文件大小
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            item.fileSize = size
        }

        // 提取元数据
        extractMetadata(for: item)

        return item
    }

    /// 提取元数据
    private func extractMetadata(for item: MediaAsset) {
        metadataQueue.async {
            switch item.type {
            case .video:
                self.extractVideoMetadata(for: item)
            case .audio, .music, .soundEffect:
                self.extractAudioMetadata(for: item)
            case .image, .gif:
                self.extractImageMetadata(for: item)
            default:
                break
            }
        }
    }

    private func extractVideoMetadata(for item: MediaAsset) {
        let asset = AVAsset(url: item.url)

        DispatchQueue.main.async {
            item.metadata.duration = asset.duration.seconds

            if let videoTrack = asset.tracks(withMediaType: .video).first {
                let size = videoTrack.naturalSize
                item.metadata.width = Int(size.width)
                item.metadata.height = Int(size.height)
                item.metadata.frameRate = Double(videoTrack.nominalFrameRate)
            }

            if let audioTrack = asset.tracks(withMediaType: .audio).first,
               let formatDescAny = audioTrack.formatDescriptions.first {
                let formatDesc = formatDescAny as! CMFormatDescription
                if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) {
                    item.metadata.audioChannels = Int(asbd.pointee.mChannelsPerFrame)
                    item.metadata.sampleRate = Int(asbd.pointee.mSampleRate)
                }
            }
        }
    }

    private func extractAudioMetadata(for item: MediaAsset) {
        let asset = AVAsset(url: item.url)

        DispatchQueue.main.async {
            item.metadata.duration = asset.duration.seconds

            if let audioTrack = asset.tracks(withMediaType: .audio).first,
               let formatDescAny = audioTrack.formatDescriptions.first {
                let formatDesc = formatDescAny as! CMFormatDescription
                if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) {
                    item.metadata.audioChannels = Int(asbd.pointee.mChannelsPerFrame)
                    item.metadata.sampleRate = Int(asbd.pointee.mSampleRate)
                }
            }
        }
    }

    private func extractImageMetadata(for item: MediaAsset) {
        guard let imageSource = CGImageSourceCreateWithURL(item.url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return
        }

        DispatchQueue.main.async {
            if let width = properties[kCGImagePropertyPixelWidth as String] as? Int {
                item.metadata.width = width
            }
            if let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
                item.metadata.height = height
            }
            if let orientation = properties[kCGImagePropertyOrientation as String] as? Int {
                item.metadata.orientation = orientation
            }

            // EXIF数据
            if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let firstISO = iso.first {
                    item.metadata.iso = firstISO
                }
                if let aperture = exif[kCGImagePropertyExifFNumber as String] as? Double {
                    item.metadata.aperture = aperture
                }
                if let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                    item.metadata.creationDate = formatter.date(from: dateString)
                }
            }

            // GPS数据
            if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                var location = MediaLocation(latitude: 0, longitude: 0)
                if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
                   let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String {
                    location.latitude = latRef == "S" ? -lat : lat
                }
                if let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
                   let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
                    location.longitude = lonRef == "W" ? -lon : lon
                }
                if let alt = gps[kCGImagePropertyGPSAltitude as String] as? Double {
                    location.altitude = alt
                }
                item.metadata.location = location
            }

            // TIFF数据
            if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                item.metadata.camera = tiff[kCGImagePropertyTIFFModel as String] as? String
            }
        }
    }

    /// 生成缩略图
    private func generateThumbnail(for item: MediaAsset) {
        metadataQueue.async { [weak self] in
            var thumbnail: CGImage?

            switch item.type {
            case .video:
                thumbnail = self?.generateVideoThumbnail(from: item.url)
            case .image, .gif:
                thumbnail = self?.generateImageThumbnail(from: item.url)
            default:
                break
            }

            if let thumb = thumbnail {
                DispatchQueue.main.async {
                    self?.thumbnailCache[item.id] = thumb

                    // 保存缩略图到磁盘
                    if let thumbnailURL = self?.saveThumbnail(thumb, for: item) {
                        item.thumbnailURL = thumbnailURL
                    }
                }
            }
        }
    }

    private func generateVideoThumbnail(from url: URL) -> CGImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)

        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: 1, preferredTimescale: 600), actualTime: nil)
            return cgImage
        } catch {
            return nil
        }
    }

    private func generateImageThumbnail(from url: URL) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: 320,
            kCGImageSourceCreateThumbnailFromImageAlways: true
        ]

        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }

    private func saveThumbnail(_ image: CGImage, for item: MediaAsset) -> URL? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let thumbnailsDir = documentsURL.appendingPathComponent("Thumbnails")

        try? fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)

        let thumbnailURL = thumbnailsDir.appendingPathComponent("\(item.id.uuidString).jpg")

        #if canImport(AppKit)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        if let tiffData = nsImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            try? jpegData.write(to: thumbnailURL)
            return thumbnailURL
        }
        #elseif canImport(UIKit)
        let uiImage = UIImage(cgImage: image)
        if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
            try? jpegData.write(to: thumbnailURL)
            return thumbnailURL
        }
        #endif

        return nil
    }

    /// AI分析媒体
    private func analyzeMedia(_ item: MediaAsset) {
        analysisQueue.async { [weak self] in
            var analysis = AIAnalysisResult(
                faces: [],
                objects: [],
                scenes: [],
                text: [],
                colors: [],
                quality: MediaQuality(sharpness: 0, exposure: 0, contrast: 0, noise: 0, blur: 0, overall: 0),
                keywords: []
            )

            switch item.type {
            case .video:
                self?.analyzeVideo(item, analysis: &analysis)
            case .image:
                self?.analyzeImage(item, analysis: &analysis)
            default:
                break
            }

            DispatchQueue.main.async {
                item.aiAnalysis = analysis
                self?.saveLibrary()
            }
        }
    }

    private func analyzeImage(_ item: MediaAsset, analysis: inout AIAnalysisResult) {
        guard let imageSource = CGImageSourceCreateWithURL(item.url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // 人脸检测
        let faceRequest = VNDetectFaceLandmarksRequest()
        // 物体检测
        let objectRequest = VNRecognizeAnimalsRequest()
        // 文字检测
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate

        try? handler.perform([faceRequest, objectRequest, textRequest])

        // 处理人脸检测结果
        if let faceResults = faceRequest.results {
            for (index, face) in faceResults.enumerated() {
                let detectedFace = DetectedFace(
                    id: "\(index)",
                    bounds: face.boundingBox,
                    confidence: face.confidence
                )
                analysis.faces.append(detectedFace)
            }
        }

        // 处理物体检测结果
        if let objectResults = objectRequest.results {
            for result in objectResults {
                if let label = result.labels.first {
                    let detectedObject = DetectedObject(
                        id: UUID().uuidString,
                        label: label.identifier,
                        confidence: label.confidence,
                        bounds: result.boundingBox
                    )
                    analysis.objects.append(detectedObject)
                }
            }
        }

        // 处理文字检测结果
        if let textResults = textRequest.results {
            for result in textResults {
                if let topCandidate = result.topCandidates(1).first {
                    let detectedText = DetectedText(
                        text: topCandidate.string,
                        bounds: result.boundingBox,
                        confidence: topCandidate.confidence
                    )
                    analysis.text.append(detectedText)
                }
            }
        }

        // 分析主色调
        analysis.colors = extractDominantColors(from: cgImage)

        // 生成关键词
        analysis.keywords = generateKeywords(from: analysis)
    }

    private func analyzeVideo(_ item: MediaAsset, analysis: inout AIAnalysisResult) {
        let asset = AVAsset(url: item.url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        // 采样几帧进行分析
        let duration = asset.duration.seconds
        let sampleTimes = [0.0, duration * 0.25, duration * 0.5, duration * 0.75].map {
            CMTime(seconds: $0, preferredTimescale: 600)
        }

        for time in sampleTimes {
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                var frameAnalysis = AIAnalysisResult(
                    faces: [],
                    objects: [],
                    scenes: [],
                    text: [],
                    colors: [],
                    quality: MediaQuality(sharpness: 0, exposure: 0, contrast: 0, noise: 0, blur: 0, overall: 0),
                    keywords: []
                )

                // 复用图片分析逻辑
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let faceRequest = VNDetectFaceLandmarksRequest { request, error in
                    if let results = request.results as? [VNFaceObservation] {
                        for (index, face) in results.enumerated() {
                            let detectedFace = DetectedFace(
                                id: "\(index)",
                                bounds: face.boundingBox,
                                confidence: face.confidence
                            )
                            frameAnalysis.faces.append(detectedFace)
                        }
                    }
                }
                try? handler.perform([faceRequest])

                // 合并结果
                analysis.faces.append(contentsOf: frameAnalysis.faces)
            }
        }

        // 去重人脸
        analysis.faces = Array(Set(analysis.faces.map { $0.id }).compactMap { id in
            analysis.faces.first { $0.id == id }
        })

        // 生成关键词
        analysis.keywords = generateKeywords(from: analysis)
    }

    private func extractDominantColors(from image: CGImage) -> [DominantColor] {
        // 简化的颜色提取
        var colors: [DominantColor] = []

        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return colors
        }

        let width = image.width
        let height = image.height
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow

        var colorBuckets: [String: (r: Float, g: Float, b: Float, count: Int)] = [:]
        let step = 10 // 采样步长

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Float(ptr[offset]) / 255.0
                let g = Float(ptr[offset + 1]) / 255.0
                let b = Float(ptr[offset + 2]) / 255.0

                // 量化颜色
                let qr = Int(r * 4) * 64
                let qg = Int(g * 4) * 64
                let qb = Int(b * 4) * 64
                let key = "\(qr),\(qg),\(qb)"

                if var bucket = colorBuckets[key] {
                    bucket.r += r
                    bucket.g += g
                    bucket.b += b
                    bucket.count += 1
                    colorBuckets[key] = bucket
                } else {
                    colorBuckets[key] = (r, g, b, 1)
                }
            }
        }

        let totalSamples = Float(colorBuckets.values.reduce(0) { $0 + $1.count })
        let sortedBuckets = colorBuckets.values.sorted { $0.count > $1.count }.prefix(5)

        for bucket in sortedBuckets {
            let avgR = bucket.r / Float(bucket.count)
            let avgG = bucket.g / Float(bucket.count)
            let avgB = bucket.b / Float(bucket.count)
            let percentage = Float(bucket.count) / totalSamples

            let color = DominantColor(
                red: avgR,
                green: avgG,
                blue: avgB,
                percentage: percentage,
                name: getColorName(r: avgR, g: avgG, b: avgB)
            )
            colors.append(color)
        }

        return colors
    }

    private func getColorName(r: Float, g: Float, b: Float) -> String {
        // 简化的颜色命名
        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)
        let delta = max - min

        if delta < 0.1 {
            if max < 0.2 { return "黑色" }
            if max > 0.8 { return "白色" }
            return "灰色"
        }

        if r >= g && r >= b {
            if g > b { return "橙色" }
            return "红色"
        } else if g >= r && g >= b {
            if b > r { return "青色" }
            return "绿色"
        } else {
            if r > g { return "紫色" }
            return "蓝色"
        }
    }

    private func generateKeywords(from analysis: AIAnalysisResult) -> [String] {
        var keywords: [String] = []

        // 从人脸
        if !analysis.faces.isEmpty {
            keywords.append("人物")
            keywords.append("\(analysis.faces.count)人")
        }

        // 从物体
        for obj in analysis.objects {
            keywords.append(obj.label)
        }

        // 从场景
        for scene in analysis.scenes {
            keywords.append(scene.label)
        }

        // 从颜色
        for color in analysis.colors.prefix(2) {
            if let name = color.name {
                keywords.append(name)
            }
        }

        return Array(Set(keywords))
    }

    // MARK: - 搜索功能

    /// 搜索媒体
    func search(query: String) -> [MediaAsset] {
        guard !query.isEmpty else {
            searchResults = items
            return items
        }

        let lowercaseQuery = query.lowercased()

        searchResults = items.filter { item in
            // 名称匹配
            if item.name.lowercased().contains(lowercaseQuery) { return true }

            // 标签匹配
            if item.tags.contains(where: { $0.lowercased().contains(lowercaseQuery) }) { return true }

            // AI关键词匹配
            if let keywords = item.aiAnalysis?.keywords,
               keywords.contains(where: { $0.lowercased().contains(lowercaseQuery) }) {
                return true
            }

            // 备注匹配
            if item.notes.lowercased().contains(lowercaseQuery) { return true }

            // 位置匹配
            if let location = item.metadata.location {
                let locationString = [location.city, location.country, location.address]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    .lowercased()
                if locationString.contains(lowercaseQuery) { return true }
            }

            return false
        }

        return searchResults
    }

    /// 高级搜索
    func advancedSearch(filter: MediaFilter) -> [MediaAsset] {
        currentFilter = filter

        searchResults = items.filter { item in
            // 类型过滤
            if let types = filter.types, !types.isEmpty {
                if !types.contains(item.type) { return false }
            }

            // 日期范围
            if let startDate = filter.startDate {
                if item.importDate < startDate { return false }
            }
            if let endDate = filter.endDate {
                if item.importDate > endDate { return false }
            }

            // 时长范围
            if let minDuration = filter.minDuration {
                if let duration = item.metadata.duration, duration < minDuration { return false }
            }
            if let maxDuration = filter.maxDuration {
                if let duration = item.metadata.duration, duration > maxDuration { return false }
            }

            // 分辨率
            if let resolution = filter.resolution {
                if let width = item.metadata.width, let height = item.metadata.height {
                    let itemResolution = min(width, height)
                    switch resolution {
                    case .sd: if itemResolution > 720 { return false }
                    case .hd: if itemResolution < 720 || itemResolution > 1080 { return false }
                    case .fullHD: if itemResolution < 1080 || itemResolution > 1440 { return false }
                    case .qhd: if itemResolution < 1440 || itemResolution > 2160 { return false }
                    case .uhd4k: if itemResolution < 2160 { return false }
                    }
                }
            }

            // 评分
            if let minRating = filter.minRating {
                if item.rating < minRating { return false }
            }

            // 收藏
            if let favorite = filter.isFavorite {
                if item.isFavorite != favorite { return false }
            }

            // 标签
            if let tags = filter.tags, !tags.isEmpty {
                if filter.matchAllTags {
                    if !tags.allSatisfy({ item.tags.contains($0) }) { return false }
                } else {
                    if !tags.contains(where: { item.tags.contains($0) }) { return false }
                }
            }

            // 颜色标签
            if let color = filter.color {
                if item.color != color { return false }
            }

            // 人脸
            if let hasFaces = filter.hasFaces {
                let itemHasFaces = !(item.aiAnalysis?.faces.isEmpty ?? true)
                if itemHasFaces != hasFaces { return false }
            }

            return true
        }

        return searchResults
    }

    // MARK: - 收藏和评分

    /// 切换收藏
    func toggleFavorite(_ item: MediaAsset) {
        item.isFavorite.toggle()
        saveLibrary()
    }

    /// 设置评分
    func setRating(_ item: MediaAsset, rating: Int) {
        item.rating = max(0, min(5, rating))
        saveLibrary()
    }

    /// 设置颜色标签
    func setColor(_ item: MediaAsset, color: String?) {
        item.color = color
        saveLibrary()
    }

    /// 添加标签
    func addTag(_ item: MediaAsset, tag: String) {
        item.tags.insert(tag)
        saveLibrary()
    }

    /// 移除标签
    func removeTag(_ item: MediaAsset, tag: String) {
        item.tags.remove(tag)
        saveLibrary()
    }

    // MARK: - 智能文件夹

    /// 创建智能文件夹
    func createSmartFolder(name: String, conditions: [SmartFolderCondition]) -> SmartFolder {
        let folder = SmartFolder(name: name, conditions: conditions)
        smartFolders.append(folder)
        saveLibrary()
        return folder
    }

    /// 获取智能文件夹内容
    func getSmartFolderContents(_ folder: SmartFolder) -> [MediaAsset] {
        var matchingItems = items.filter { folder.matches($0) }

        // 排序
        switch folder.sortBy {
        case .name:
            matchingItems.sort { folder.sortAscending ? $0.name < $1.name : $0.name > $1.name }
        case .date:
            matchingItems.sort { folder.sortAscending ? $0.importDate < $1.importDate : $0.importDate > $1.importDate }
        case .duration:
            matchingItems.sort { (a, b) in
                let dA = a.metadata.duration ?? 0
                let dB = b.metadata.duration ?? 0
                return folder.sortAscending ? dA < dB : dA > dB
            }
        case .fileSize:
            matchingItems.sort { folder.sortAscending ? $0.fileSize < $1.fileSize : $0.fileSize > $1.fileSize }
        case .rating:
            matchingItems.sort { folder.sortAscending ? $0.rating < $1.rating : $0.rating > $1.rating }
        case .usageCount:
            matchingItems.sort { folder.sortAscending ? $0.usageCount < $1.usageCount : $0.usageCount > $1.usageCount }
        case .type:
            matchingItems.sort { folder.sortAscending ? $0.type.rawValue < $1.type.rawValue : $0.type.rawValue > $1.type.rawValue }
        }

        // 限制数量
        if let limit = folder.limit {
            matchingItems = Array(matchingItems.prefix(limit))
        }

        return matchingItems
    }

    private func createDefaultSmartFolders() {
        if smartFolders.isEmpty {
            // 最近导入
            let recentFolder = SmartFolder(name: "最近导入", conditions: [
                SmartFolderCondition(field: .date, comparison: .greaterThan, value: getDateString(daysAgo: 7), conjunction: .and)
            ])
            recentFolder.icon = "clock.fill"
            recentFolder.sortBy = .date
            smartFolders.append(recentFolder)

            // 收藏
            let favoritesFolder = SmartFolder(name: "收藏", conditions: [
                SmartFolderCondition(field: .favorite, comparison: .equals, value: "true", conjunction: .and)
            ])
            favoritesFolder.icon = "heart.fill"
            favoritesFolder.color = "red"
            smartFolders.append(favoritesFolder)

            // 高评分
            let topRatedFolder = SmartFolder(name: "高评分", conditions: [
                SmartFolderCondition(field: .rating, comparison: .greaterThan, value: "3", conjunction: .and)
            ])
            topRatedFolder.icon = "star.fill"
            topRatedFolder.color = "yellow"
            topRatedFolder.sortBy = .rating
            smartFolders.append(topRatedFolder)

            // 视频
            let videosFolder = SmartFolder(name: "所有视频", conditions: [
                SmartFolderCondition(field: .type, comparison: .equals, value: "video", conjunction: .and)
            ])
            videosFolder.icon = "video.fill"
            smartFolders.append(videosFolder)

            // 图片
            let imagesFolder = SmartFolder(name: "所有图片", conditions: [
                SmartFolderCondition(field: .type, comparison: .equals, value: "image", conjunction: .and)
            ])
            imagesFolder.icon = "photo.fill"
            smartFolders.append(imagesFolder)

            // 音频
            let audioFolder = SmartFolder(name: "所有音频", conditions: [
                SmartFolderCondition(field: .type, comparison: .equals, value: "audio", conjunction: .or),
                SmartFolderCondition(field: .type, comparison: .equals, value: "music", conjunction: .or)
            ])
            audioFolder.icon = "music.note"
            audioFolder.matchAll = false
            smartFolders.append(audioFolder)

            // 长视频
            let longVideosFolder = SmartFolder(name: "长视频 (>5分钟)", conditions: [
                SmartFolderCondition(field: .type, comparison: .equals, value: "video", conjunction: .and),
                SmartFolderCondition(field: .duration, comparison: .greaterThan, value: "300", conjunction: .and)
            ])
            longVideosFolder.icon = "film.fill"
            smartFolders.append(longVideosFolder)

            // 有人物
            let peopleFolder = SmartFolder(name: "有人物", conditions: [
                SmartFolderCondition(field: .face, comparison: .isNotEmpty, value: "", conjunction: .and)
            ])
            peopleFolder.icon = "person.2.fill"
            smartFolders.append(peopleFolder)
        }
    }

    private func getDateString(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - 收藏集

    /// 创建收藏集
    func createCollection(name: String, items: [MediaAsset] = []) -> MediaCollection {
        let collection = MediaCollection(name: name)
        collection.items = items.map { $0.id }
        collections.append(collection)
        saveLibrary()
        return collection
    }

    /// 添加到收藏集
    func addToCollection(_ item: MediaAsset, collection: MediaCollection) {
        if !collection.items.contains(item.id) {
            collection.items.append(item.id)
            saveLibrary()
        }
    }

    /// 从收藏集移除
    func removeFromCollection(_ item: MediaAsset, collection: MediaCollection) {
        collection.items.removeAll { $0 == item.id }
        saveLibrary()
    }

    /// 获取收藏集内容
    func getCollectionContents(_ collection: MediaCollection) -> [MediaAsset] {
        return collection.items.compactMap { itemId in
            items.first { $0.id == itemId }
        }
    }

    // MARK: - 删除和清理

    /// 删除媒体项目
    func deleteItem(_ item: MediaAsset, deleteFile: Bool = false) {
        if deleteFile {
            try? FileManager.default.removeItem(at: item.url)
        }

        // 删除缩略图
        if let thumbnailURL = item.thumbnailURL {
            try? FileManager.default.removeItem(at: thumbnailURL)
        }

        // 删除代理
        if let proxyURL = item.proxyURL {
            try? FileManager.default.removeItem(at: proxyURL)
        }

        items.removeAll { $0.id == item.id }
        thumbnailCache.removeValue(forKey: item.id)

        // 从收藏集移除
        for collection in collections {
            collection.items.removeAll { $0 == item.id }
        }

        saveLibrary()
    }

    /// 批量删除
    func deleteItems(_ itemsToDelete: [MediaAsset], deleteFiles: Bool = false) {
        for item in itemsToDelete {
            deleteItem(item, deleteFile: deleteFiles)
        }
    }

    /// 清理缓存
    func clearCache() {
        thumbnailCache.removeAll()

        // 清理缩略图目录
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let thumbnailsDir = documentsURL.appendingPathComponent("Thumbnails")
        try? fileManager.removeItem(at: thumbnailsDir)
        try? fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
    }

    /// 查找重复
    func findDuplicates() -> [[MediaAsset]] {
        var duplicates: [[MediaAsset]] = []
        var checked: Set<UUID> = []

        for item in items {
            if checked.contains(item.id) { continue }

            let potentialDuplicates = items.filter { other in
                guard other.id != item.id else { return false }

                // 检查文件大小和类型
                if item.fileSize == other.fileSize && item.type == other.type {
                    // 进一步检查元数据
                    if item.metadata.duration == other.metadata.duration &&
                       item.metadata.width == other.metadata.width &&
                       item.metadata.height == other.metadata.height {
                        return true
                    }
                }
                return false
            }

            if !potentialDuplicates.isEmpty {
                var group = [item]
                group.append(contentsOf: potentialDuplicates)
                duplicates.append(group)

                for dup in potentialDuplicates {
                    checked.insert(dup.id)
                }
            }

            checked.insert(item.id)
        }

        return duplicates
    }

    /// 查找未使用
    func findUnused() -> [MediaAsset] {
        return items.filter { $0.usageCount == 0 && $0.linkedProjects.isEmpty }
    }

    // MARK: - 持久化

    private func loadLibrary() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let libraryURL = documentsURL.appendingPathComponent("media_library.json")

        if let data = try? Data(contentsOf: libraryURL) {
            let decoder = JSONDecoder()
            if let library = try? decoder.decode(MediaLibraryData.self, from: data) {
                self.items = library.items
                self.smartFolders = library.smartFolders
                self.collections = library.collections
            }
        }
    }

    private func saveLibrary() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let libraryURL = documentsURL.appendingPathComponent("media_library.json")

        let library = MediaLibraryData(items: items, smartFolders: smartFolders, collections: collections)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        if let data = try? encoder.encode(library) {
            try? data.write(to: libraryURL)
        }
    }

    /// 获取缩略图
    func getThumbnail(for item: MediaAsset) -> CGImage? {
        if let cached = thumbnailCache[item.id] {
            return cached
        }

        if let thumbnailURL = item.thumbnailURL,
           let imageSource = CGImageSourceCreateWithURL(thumbnailURL as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
            thumbnailCache[item.id] = image
            return image
        }

        return nil
    }
}

/// 媒体库数据
struct MediaLibraryData: Codable {
    var items: [MediaAsset]
    var smartFolders: [SmartFolder]
    var collections: [MediaCollection]
}

/// 媒体收藏集
class MediaCollection: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var name: String
    @Published var description: String
    @Published var coverImageId: UUID?
    @Published var items: [UUID]
    @Published var createdDate: Date
    @Published var modifiedDate: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description, coverImageId, items, createdDate, modifiedDate
    }

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.description = ""
        self.items = []
        self.createdDate = Date()
        self.modifiedDate = Date()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        coverImageId = try container.decodeIfPresent(UUID.self, forKey: .coverImageId)
        items = try container.decode([UUID].self, forKey: .items)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        modifiedDate = try container.decode(Date.self, forKey: .modifiedDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(coverImageId, forKey: .coverImageId)
        try container.encode(items, forKey: .items)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(modifiedDate, forKey: .modifiedDate)
    }
}

/// 媒体过滤器
struct MediaFilter {
    var types: [MediaType]?
    var startDate: Date?
    var endDate: Date?
    var minDuration: Double?
    var maxDuration: Double?
    var resolution: VideoResolution?
    var minRating: Int?
    var isFavorite: Bool?
    var tags: [String]?
    var matchAllTags: Bool = true
    var color: String?
    var hasFaces: Bool?
    var query: String?

    enum VideoResolution: String, CaseIterable {
        case sd = "SD"
        case hd = "720p"
        case fullHD = "1080p"
        case qhd = "1440p"
        case uhd4k = "4K"
    }
}

// MARK: - 云素材库

/// 云素材库
class CloudAssetLibrary: ObservableObject {
    static let shared = CloudAssetLibrary()

    @Published var categories: [AssetCategory] = []
    @Published var featuredAssets: [CloudAsset] = []
    @Published var recentAssets: [CloudAsset] = []
    @Published var downloadedAssets: [CloudAsset] = []
    @Published var isLoading: Bool = false

    init() {
        loadCategories()
    }

    /// 加载分类
    func loadCategories() {
        categories = [
            AssetCategory(id: "music", name: "音乐", icon: "music.note", subcategories: [
                AssetSubcategory(id: "pop", name: "流行"),
                AssetSubcategory(id: "rock", name: "摇滚"),
                AssetSubcategory(id: "electronic", name: "电子"),
                AssetSubcategory(id: "classical", name: "古典"),
                AssetSubcategory(id: "jazz", name: "爵士"),
                AssetSubcategory(id: "ambient", name: "环境音乐"),
                AssetSubcategory(id: "cinematic", name: "电影配乐")
            ]),
            AssetCategory(id: "sound_effects", name: "音效", icon: "speaker.wave.2.fill", subcategories: [
                AssetSubcategory(id: "transition", name: "转场音效"),
                AssetSubcategory(id: "whoosh", name: "呼啸"),
                AssetSubcategory(id: "impact", name: "撞击"),
                AssetSubcategory(id: "ui", name: "UI音效"),
                AssetSubcategory(id: "nature", name: "自然"),
                AssetSubcategory(id: "urban", name: "城市"),
                AssetSubcategory(id: "cartoon", name: "卡通")
            ]),
            AssetCategory(id: "video", name: "视频素材", icon: "video.fill", subcategories: [
                AssetSubcategory(id: "backgrounds", name: "背景"),
                AssetSubcategory(id: "overlays", name: "叠加层"),
                AssetSubcategory(id: "transitions", name: "转场"),
                AssetSubcategory(id: "intros", name: "片头"),
                AssetSubcategory(id: "outros", name: "片尾"),
                AssetSubcategory(id: "lower_thirds", name: "字幕条")
            ]),
            AssetCategory(id: "images", name: "图片素材", icon: "photo.fill", subcategories: [
                AssetSubcategory(id: "backgrounds", name: "背景"),
                AssetSubcategory(id: "textures", name: "纹理"),
                AssetSubcategory(id: "overlays", name: "叠加"),
                AssetSubcategory(id: "icons", name: "图标"),
                AssetSubcategory(id: "frames", name: "边框")
            ]),
            AssetCategory(id: "stickers", name: "贴纸", icon: "face.smiling.fill", subcategories: [
                AssetSubcategory(id: "emoji", name: "表情"),
                AssetSubcategory(id: "animated", name: "动态贴纸"),
                AssetSubcategory(id: "text", name: "文字贴纸"),
                AssetSubcategory(id: "decorations", name: "装饰")
            ]),
            AssetCategory(id: "effects", name: "特效", icon: "sparkles", subcategories: [
                AssetSubcategory(id: "particles", name: "粒子"),
                AssetSubcategory(id: "light", name: "光效"),
                AssetSubcategory(id: "glitch", name: "故障"),
                AssetSubcategory(id: "film", name: "胶片")
            ]),
            AssetCategory(id: "luts", name: "调色", icon: "cube.fill", subcategories: [
                AssetSubcategory(id: "cinematic", name: "电影感"),
                AssetSubcategory(id: "vintage", name: "复古"),
                AssetSubcategory(id: "vibrant", name: "鲜艳"),
                AssetSubcategory(id: "moody", name: "情绪"),
                AssetSubcategory(id: "black_white", name: "黑白")
            ]),
            AssetCategory(id: "fonts", name: "字体", icon: "textformat", subcategories: [
                AssetSubcategory(id: "sans_serif", name: "无衬线"),
                AssetSubcategory(id: "serif", name: "衬线"),
                AssetSubcategory(id: "handwritten", name: "手写"),
                AssetSubcategory(id: "display", name: "展示"),
                AssetSubcategory(id: "chinese", name: "中文")
            ])
        ]
    }

    /// 搜索素材
    func searchAssets(query: String, category: String? = nil) async -> [CloudAsset] {
        isLoading = true
        defer { isLoading = false }

        // 模拟API调用
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 返回模拟数据
        return generateMockAssets(count: 20, category: category)
    }

    /// 获取分类素材
    func getAssets(category: String, subcategory: String? = nil, page: Int = 1) async -> [CloudAsset] {
        isLoading = true
        defer { isLoading = false }

        try? await Task.sleep(nanoseconds: 300_000_000)

        return generateMockAssets(count: 30, category: category)
    }

    /// 下载素材
    func downloadAsset(_ asset: CloudAsset, progress: @escaping (Double) -> Void) async -> URL? {
        // 模拟下载
        for i in 0...10 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                progress(Double(i) / 10.0)
            }
        }

        // 创建本地文件路径
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let assetsDir = documentsURL.appendingPathComponent("CloudAssets")
        try? fileManager.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        let localURL = assetsDir.appendingPathComponent(asset.filename)

        await MainActor.run {
            var mutableAsset = asset
            mutableAsset.localURL = localURL
            mutableAsset.isDownloaded = true
            downloadedAssets.append(mutableAsset)
        }

        return localURL
    }

    /// 删除已下载素材
    func deleteDownloadedAsset(_ asset: CloudAsset) {
        if let localURL = asset.localURL {
            try? FileManager.default.removeItem(at: localURL)
        }
        downloadedAssets.removeAll { $0.id == asset.id }
    }

    /// 生成模拟数据
    private func generateMockAssets(count: Int, category: String?) -> [CloudAsset] {
        var assets: [CloudAsset] = []

        for i in 0..<count {
            let asset = CloudAsset(
                id: UUID().uuidString,
                name: "素材 \(i + 1)",
                category: category ?? "music",
                subcategory: "pop",
                filename: "asset_\(i).mp3",
                fileSize: Int64.random(in: 100000...10000000),
                duration: Double.random(in: 10...180),
                thumbnailURL: nil,
                previewURL: nil,
                downloadURL: nil,
                author: "Creator \(i % 10)",
                license: "免费使用",
                tags: ["标签1", "标签2"],
                downloadCount: Int.random(in: 100...10000),
                rating: Float.random(in: 3.5...5.0),
                isPremium: i % 5 == 0,
                price: i % 5 == 0 ? Double.random(in: 1...10) : nil
            )
            assets.append(asset)
        }

        return assets
    }
}

/// 素材分类
struct AssetCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    var subcategories: [AssetSubcategory]
}

/// 素材子分类
struct AssetSubcategory: Identifiable {
    let id: String
    let name: String
}

/// 云素材
struct CloudAsset: Identifiable {
    let id: String
    var name: String
    var category: String
    var subcategory: String
    var filename: String
    var fileSize: Int64
    var duration: Double?
    var thumbnailURL: URL?
    var previewURL: URL?
    var downloadURL: URL?
    var author: String
    var license: String
    var tags: [String]
    var downloadCount: Int
    var rating: Float
    var isPremium: Bool
    var price: Double?
    var isDownloaded: Bool = false
    var localURL: URL?
}

// MARK: - 人脸识别管理

/// 人脸识别管理器
class FaceRecognitionManager: ObservableObject {
    static let shared = FaceRecognitionManager()

    @Published var knownPeople: [KnownPerson] = []
    @Published var unidentifiedFaces: [UnidentifiedFace] = []

    init() {
        loadPeople()
    }

    /// 添加已知人物
    func addPerson(name: String, faces: [CGImage]) -> KnownPerson {
        let person = KnownPerson(name: name)

        for face in faces {
            if let embedding = generateFaceEmbedding(from: face) {
                person.faceEmbeddings.append(embedding)
            }
        }

        knownPeople.append(person)
        savePeople()
        return person
    }

    /// 识别人脸
    func identifyFace(_ faceImage: CGImage) -> KnownPerson? {
        guard let embedding = generateFaceEmbedding(from: faceImage) else { return nil }

        var bestMatch: KnownPerson?
        var bestSimilarity: Float = 0.7 // 阈值

        for person in knownPeople {
            for knownEmbedding in person.faceEmbeddings {
                let similarity = cosineSimilarity(embedding, knownEmbedding)
                if similarity > bestSimilarity {
                    bestSimilarity = similarity
                    bestMatch = person
                }
            }
        }

        return bestMatch
    }

    /// 合并人物
    func mergePeople(_ people: [KnownPerson], into target: KnownPerson) {
        for person in people where person.id != target.id {
            target.faceEmbeddings.append(contentsOf: person.faceEmbeddings)
            knownPeople.removeAll { $0.id == person.id }
        }
        savePeople()
    }

    /// 生成人脸特征
    private func generateFaceEmbedding(from image: CGImage) -> [Float]? {
        // 这里应该使用Vision框架或CoreML模型生成人脸特征向量
        // 简化实现，返回随机向量
        return (0..<128).map { _ in Float.random(in: -1...1) }
    }

    /// 计算余弦相似度
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }

    private func loadPeople() {
        // 从本地加载
    }

    private func savePeople() {
        // 保存到本地
    }
}

/// 已知人物
class KnownPerson: Identifiable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var faceEmbeddings: [[Float]]
    @Published var thumbnailImage: CGImage?
    @Published var mediaAppearances: [UUID] // 出现的媒体ID列表

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.faceEmbeddings = []
        self.mediaAppearances = []
    }
}

/// 未识别人脸
struct UnidentifiedFace: Identifiable {
    let id: UUID
    let image: CGImage
    let mediaItemId: UUID
    let timestamp: Double?
    let bounds: CGRect
}
