import Foundation
import AVFoundation

// MARK: - 可序列化的项目模型

/// 可序列化的项目数据
struct ProjectData: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    var settings: ProjectSettings
    var tracks: [TrackData]
    var textOverlays: [TextOverlayData]
    var transitions: [TransitionData]
    var globalFilter: FilterData?

    /// 版本号（用于迁移）
    var version: Int = 1

    init(from project: Project) {
        self.id = project.id
        self.name = project.name
        self.createdAt = project.createdAt
        self.modifiedAt = project.modifiedAt
        self.settings = project.settings
        self.tracks = project.tracks.map { TrackData(from: $0) }
        self.textOverlays = project.textOverlays.map { TextOverlayData(from: $0) }
        self.transitions = project.transitions.map { TransitionData(from: $0) }
        self.globalFilter = project.globalFilter.map { FilterData(from: $0) }
    }
}

/// 可序列化的轨道数据
struct TrackData: Codable {
    var id: UUID
    var name: String
    var type: TrackType
    var clips: [ClipData]
    var isMuted: Bool
    var isLocked: Bool
    var isVisible: Bool
    var volume: Float

    init(from track: Track) {
        self.id = track.id
        self.name = track.name
        self.type = track.type
        self.clips = track.clips.map { ClipData(from: $0) }
        self.isMuted = track.isMuted
        self.isLocked = track.isLocked
        self.isVisible = track.isVisible
        self.volume = track.volume
    }
}

/// 可序列化的片段数据
struct ClipData: Codable {
    var id: UUID
    var sourceURL: String  // 相对路径或绝对路径
    var sourceTimeRangeStart: Double
    var sourceTimeRangeDuration: Double
    var startTime: Double
    var type: ClipType
    var name: String
    var volume: Float
    var speed: Float
    var filter: FilterData?
    var transform: ClipTransformData

    init(from clip: Clip) {
        self.id = clip.id
        self.sourceURL = clip.sourceURL.path
        self.sourceTimeRangeStart = CMTimeGetSeconds(clip.sourceTimeRange.start)
        self.sourceTimeRangeDuration = CMTimeGetSeconds(clip.sourceTimeRange.duration)
        self.startTime = CMTimeGetSeconds(clip.startTime)
        self.type = clip.type
        self.name = clip.name
        self.volume = clip.volume
        self.speed = clip.speed
        self.filter = clip.filter.map { FilterData(from: $0) }
        self.transform = ClipTransformData(from: clip.transform)
    }
}

/// 可序列化的变换数据
struct ClipTransformData: Codable {
    var positionX: CGFloat
    var positionY: CGFloat
    var scale: CGFloat
    var rotation: CGFloat
    var opacity: CGFloat
    var flipHorizontal: Bool
    var flipVertical: Bool

    init(from transform: ClipTransform) {
        self.positionX = transform.position.x
        self.positionY = transform.position.y
        self.scale = transform.scale
        self.rotation = transform.rotation
        self.opacity = transform.opacity
        self.flipHorizontal = transform.flipHorizontal
        self.flipVertical = transform.flipVertical
    }

    func toClipTransform() -> ClipTransform {
        var transform = ClipTransform()
        transform.position = CGPoint(x: positionX, y: positionY)
        transform.scale = scale
        transform.rotation = rotation
        transform.opacity = opacity
        transform.flipHorizontal = flipHorizontal
        transform.flipVertical = flipVertical
        return transform
    }
}

/// 可序列化的滤镜数据
struct FilterData: Codable {
    var id: UUID
    var type: String
    var intensity: Float
    var brightness: Float
    var contrast: Float
    var saturation: Float
    var exposure: Float
    var temperature: Float
    var tint: Float
    var highlights: Float
    var shadows: Float
    var vibrance: Float
    var sharpness: Float
    var vignette: Float
    var grain: Float

    init(from filter: VideoEffects) {
        self.id = UUID()
        self.type = "VideoEffects"
        self.intensity = filter.intensity
        self.brightness = filter.brightness
        self.contrast = filter.contrast
        self.saturation = filter.saturation
        self.exposure = filter.exposure
        self.temperature = filter.temperature
        self.tint = filter.tint
        self.highlights = filter.highlights
        self.shadows = filter.shadows
        self.vibrance = filter.vibrance
        self.sharpness = filter.sharpness
        self.vignette = filter.vignette
        self.grain = filter.grain
    }

    func toVideoEffects() -> VideoEffects {
        return VideoEffects(
            intensity: intensity,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            exposure: exposure,
            temperature: temperature,
            tint: tint,
            highlights: highlights,
            shadows: shadows,
            vibrance: vibrance,
            sharpness: sharpness,
            vignette: vignette,
            grain: grain
        )
    }
}

/// 可序列化的文字覆盖层数据
struct TextOverlayData: Codable {
    var id: UUID
    var text: String
    var fontSize: CGFloat
    var fontWeight: String
    var textColorRed: CGFloat
    var textColorGreen: CGFloat
    var textColorBlue: CGFloat
    var textColorAlpha: CGFloat
    var position: String
    var animation: String
    var timeRangeStart: Double
    var timeRangeDuration: Double

    init(from overlay: TextOverlay) {
        self.id = overlay.id
        self.text = overlay.text
        self.fontSize = overlay.fontSize
        self.fontWeight = overlay.fontWeight.rawValue
        self.textColorRed = overlay.textColor.red
        self.textColorGreen = overlay.textColor.green
        self.textColorBlue = overlay.textColor.blue
        self.textColorAlpha = overlay.textColor.alpha
        self.position = overlay.position.rawValue
        self.animation = overlay.animation.rawValue
        self.timeRangeStart = CMTimeGetSeconds(overlay.timeRange.start)
        self.timeRangeDuration = CMTimeGetSeconds(overlay.timeRange.duration)
    }
}

/// 可序列化的转场数据
struct TransitionData: Codable {
    var id: UUID
    var type: String
    var duration: Double
    var fromClipId: UUID
    var toClipId: UUID

    init(from transition: Transition) {
        self.id = transition.id
        self.type = transition.type.rawValue
        self.duration = CMTimeGetSeconds(transition.duration)
        self.fromClipId = transition.fromClipId
        self.toClipId = transition.toClipId
    }
}

// MARK: - 项目管理器

/// 项目管理器
class ProjectManagerShared: ObservableObject {

    /// 项目文件扩展名
    static let projectExtension = "vproj"

    /// 项目目录
    static var projectsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let projectsPath = documentsPath.appendingPathComponent("VideoEditor Projects")

        if !FileManager.default.fileExists(atPath: projectsPath.path) {
            try? FileManager.default.createDirectory(at: projectsPath, withIntermediateDirectories: true)
        }

        return projectsPath
    }

    /// 最近项目
    @Published var recentProjects: [ProjectInfo] = []

    /// 自动保存定时器
    private var autoSaveTimer: Timer?

    /// 当前项目路径
    private var currentProjectURL: URL?

    init() {
        loadRecentProjects()
    }

    // MARK: - 保存

    /// 保存项目
    func save(project: Project, to url: URL? = nil) throws {
        let targetURL = url ?? currentProjectURL ?? generateProjectURL(for: project)
        currentProjectURL = targetURL

        // 创建项目目录
        let projectDir = targetURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: projectDir.path) {
            try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        }

        // 序列化项目
        let projectData = ProjectData(from: project)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(projectData)
        try data.write(to: targetURL)

        // 更新最近项目
        addToRecentProjects(ProjectInfo(
            url: targetURL,
            name: project.name,
            modifiedAt: Date()
        ))

        print("项目已保存到: \(targetURL.path)")
    }

    /// 生成项目 URL
    private func generateProjectURL(for project: Project) -> URL {
        let fileName = "\(project.name)_\(project.id.uuidString.prefix(8)).\(Self.projectExtension)"
        return Self.projectsDirectory.appendingPathComponent(fileName)
    }

    // MARK: - 加载

    /// 加载项目
    func load(from url: URL) async throws -> Project {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let projectData = try decoder.decode(ProjectData.self, from: data)

        // 重建项目
        var project = Project(
            id: projectData.id,
            name: projectData.name,
            settings: projectData.settings
        )
        project.createdAt = projectData.createdAt
        project.modifiedAt = projectData.modifiedAt

        // 重建轨道
        project.tracks = []
        for trackData in projectData.tracks {
            var track = Track(
                id: trackData.id,
                name: trackData.name,
                type: trackData.type
            )
            track.isMuted = trackData.isMuted
            track.isLocked = trackData.isLocked
            track.isVisible = trackData.isVisible
            track.volume = trackData.volume

            // 重建片段
            for clipData in trackData.clips {
                let sourceURL = URL(fileURLWithPath: clipData.sourceURL)

                // 检查文件是否存在
                guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                    print("警告：找不到媒体文件 \(sourceURL.path)")
                    continue
                }

                let asset = AVAsset(url: sourceURL)

                var clip = Clip(
                    id: clipData.id,
                    asset: asset,
                    sourceURL: sourceURL,
                    sourceTimeRange: CMTimeRange(
                        start: CMTime(seconds: clipData.sourceTimeRangeStart, preferredTimescale: 600),
                        duration: CMTime(seconds: clipData.sourceTimeRangeDuration, preferredTimescale: 600)
                    ),
                    startTime: CMTime(seconds: clipData.startTime, preferredTimescale: 600),
                    type: clipData.type,
                    name: clipData.name
                )
                clip.volume = clipData.volume
                clip.speed = clipData.speed
                clip.filter = clipData.filter?.toVideoEffects()
                clip.transform = clipData.transform.toClipTransform()

                track.clips.append(clip)
            }

            project.tracks.append(track)
        }

        // 重建转场
        project.transitions = projectData.transitions.map { data in
            Transition(
                id: data.id,
                type: TransitionType(rawValue: data.type) ?? .crossDissolve,
                duration: CMTime(seconds: data.duration, preferredTimescale: 600),
                fromClipId: data.fromClipId,
                toClipId: data.toClipId
            )
        }

        // 重建全局滤镜
        project.globalFilter = projectData.globalFilter?.toVideoEffects()

        currentProjectURL = url

        // 更新最近项目
        addToRecentProjects(ProjectInfo(
            url: url,
            name: project.name,
            modifiedAt: Date()
        ))

        return project
    }

    // MARK: - 自动保存

    /// 启用自动保存
    func enableAutoSave(project: Project, interval: TimeInterval = 60) {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                try? self?.save(project: project)
            }
        }
    }

    /// 禁用自动保存
    func disableAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    // MARK: - 最近项目

    /// 项目信息
    struct ProjectInfo: Codable, Identifiable {
        var id: String { url.path }
        var url: URL
        var name: String
        var modifiedAt: Date
        var thumbnailPath: String?
    }

    /// 加载最近项目列表
    private func loadRecentProjects() {
        let recentProjectsURL = Self.projectsDirectory.appendingPathComponent(".recent_projects.json")

        guard let data = try? Data(contentsOf: recentProjectsURL),
              let projects = try? JSONDecoder().decode([ProjectInfo].self, from: data) else {
            return
        }

        // 过滤掉不存在的项目
        recentProjects = projects.filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    /// 保存最近项目列表
    private func saveRecentProjects() {
        let recentProjectsURL = Self.projectsDirectory.appendingPathComponent(".recent_projects.json")

        if let data = try? JSONEncoder().encode(recentProjects) {
            try? data.write(to: recentProjectsURL)
        }
    }

    /// 添加到最近项目
    private func addToRecentProjects(_ info: ProjectInfo) {
        recentProjects.removeAll { $0.url == info.url }
        recentProjects.insert(info, at: 0)

        // 保留最近 10 个项目
        if recentProjects.count > 10 {
            recentProjects = Array(recentProjects.prefix(10))
        }

        saveRecentProjects()
    }

    /// 从最近项目中移除
    func removeFromRecentProjects(url: URL) {
        recentProjects.removeAll { $0.url == url }
        saveRecentProjects()
    }

    /// 清空最近项目
    func clearRecentProjects() {
        recentProjects = []
        saveRecentProjects()
    }

    // MARK: - 项目模板

    /// 项目模板
    struct ProjectTemplate: Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var settings: ProjectSettings
        var icon: String
    }

    /// 内置模板
    static let builtInTemplates: [ProjectTemplate] = [
        ProjectTemplate(
            name: "空白项目",
            description: "从零开始创建",
            settings: ProjectSettings(),
            icon: "doc"
        ),
        ProjectTemplate(
            name: "抖音/TikTok",
            description: "9:16 竖屏，适合短视频",
            settings: ProjectSettings(resolution: .vertical1080x1920, frameRate: 30),
            icon: "iphone"
        ),
        ProjectTemplate(
            name: "YouTube",
            description: "16:9 横屏，1080p",
            settings: ProjectSettings(resolution: .hd1080p, frameRate: 30),
            icon: "play.rectangle"
        ),
        ProjectTemplate(
            name: "4K 电影",
            description: "4K 分辨率，24fps 电影感",
            settings: ProjectSettings(resolution: .uhd4k, frameRate: 24),
            icon: "film"
        ),
        ProjectTemplate(
            name: "Instagram Reels",
            description: "9:16 竖屏，适合 Reels",
            settings: ProjectSettings(resolution: .vertical1080x1920, frameRate: 30),
            icon: "camera"
        )
    ]

    /// 从模板创建项目
    func createFromTemplate(_ template: ProjectTemplate, name: String) -> Project {
        var project = Project(name: name, settings: template.settings)
        return project
    }

    // MARK: - 项目备份

    /// 创建项目备份
    func createBackup(of project: Project) throws -> URL {
        let backupDir = Self.projectsDirectory.appendingPathComponent("Backups")
        if !FileManager.default.fileExists(atPath: backupDir.path) {
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let backupName = "\(project.name)_backup_\(timestamp).\(Self.projectExtension)"
        let backupURL = backupDir.appendingPathComponent(backupName)

        try save(project: project, to: backupURL)

        return backupURL
    }

    /// 获取项目的所有备份
    func getBackups(for projectName: String) -> [URL] {
        let backupDir = Self.projectsDirectory.appendingPathComponent("Backups")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return files
            .filter { $0.lastPathComponent.hasPrefix(projectName) }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return date1 > date2
            }
    }
}

/// 项目错误
enum ProjectError: LocalizedError {
    case invalidProjectBundle
    case mediaNotFound
    case saveFailed
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .invalidProjectBundle: return "无效的项目包"
        case .mediaNotFound: return "找不到媒体文件"
        case .saveFailed: return "保存失败"
        case .loadFailed: return "加载失败"
        }
    }
}
