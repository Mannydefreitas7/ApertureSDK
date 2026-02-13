import Foundation
import AVFoundation

// MARK: - Serializable Project Models

/// Serializable project data
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

    /// Version number (for migration)
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

/// Serializable track data
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

/// Serializable clip data
struct ClipData: Codable {
    var id: UUID
    var sourceURL: String  // Relative or absolute path
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

/// Serializable transform data
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

/// Serializable filter data
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

/// Serializable text overlay data
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

/// Serializable transition data
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

// MARK: - Project Manager

/// Project manager
class ProjectManagerShared: ObservableObject {

    /// Project file extension
    static let projectExtension = "vproj"

    /// Projects directory
    static var projectsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let projectsPath = documentsPath.appendingPathComponent("VideoEditor Projects")

        if !FileManager.default.fileExists(atPath: projectsPath.path) {
            try? FileManager.default.createDirectory(at: projectsPath, withIntermediateDirectories: true)
        }

        return projectsPath
    }

    /// Recent projects
    @Published var recentProjects: [ProjectInfo] = []

    /// Auto-save timer
    private var autoSaveTimer: Timer?

    /// Current project path
    private var currentProjectURL: URL?

    init() {
        loadRecentProjects()
    }

    // MARK: - Save

    /// Save project
    func save(project: Project, to url: URL? = nil) throws {
        let targetURL = url ?? currentProjectURL ?? generateProjectURL(for: project)
        currentProjectURL = targetURL

        // Create project directory
        let projectDir = targetURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: projectDir.path) {
            try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        }

        // Serialize project
        let projectData = ProjectData(from: project)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(projectData)
        try data.write(to: targetURL)

        // Update recent projects
        addToRecentProjects(ProjectInfo(
            url: targetURL,
            name: project.name,
            modifiedAt: Date()
        ))

        print("Project saved to: \(targetURL.path)")
    }

    /// Generate project URL
    private func generateProjectURL(for project: Project) -> URL {
        let fileName = "\(project.name)_\(project.id.uuidString.prefix(8)).\(Self.projectExtension)"
        return Self.projectsDirectory.appendingPathComponent(fileName)
    }

    // MARK: - Load

    /// Load project
    func load(from url: URL) async throws -> Project {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let projectData = try decoder.decode(ProjectData.self, from: data)

        // Rebuild project
        var project = Project(
            id: projectData.id,
            name: projectData.name,
            settings: projectData.settings
        )
        project.createdAt = projectData.createdAt
        project.modifiedAt = projectData.modifiedAt

        // Rebuild tracks
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

            // Rebuild clips
            for clipData in trackData.clips {
                let sourceURL = URL(fileURLWithPath: clipData.sourceURL)

                // Check if file exists
                guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                    print("Warning: Cannot find media file \(sourceURL.path)")
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

        // Rebuild transitions
        project.transitions = projectData.transitions.map { data in
            Transition(
                id: data.id,
                type: TransitionType(rawValue: data.type) ?? .crossDissolve,
                duration: CMTime(seconds: data.duration, preferredTimescale: 600),
                fromClipId: data.fromClipId,
                toClipId: data.toClipId
            )
        }

        // Rebuild global filter
        project.globalFilter = projectData.globalFilter?.toVideoEffects()

        currentProjectURL = url

        // Update recent projects
        addToRecentProjects(ProjectInfo(
            url: url,
            name: project.name,
            modifiedAt: Date()
        ))

        return project
    }

    // MARK: - Auto Save

    /// Enable auto save
    func enableAutoSave(project: Project, interval: TimeInterval = 60) {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                try? self?.save(project: project)
            }
        }
    }

    /// Disable auto save
    func disableAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    // MARK: - Recent Projects

    /// Project information
    struct ProjectInfo: Codable, Identifiable {
        var id: String { url.path }
        var url: URL
        var name: String
        var modifiedAt: Date
        var thumbnailPath: String?
    }

    /// Load recent projects list
    private func loadRecentProjects() {
        let recentProjectsURL = Self.projectsDirectory.appendingPathComponent(".recent_projects.json")

        guard let data = try? Data(contentsOf: recentProjectsURL),
              let projects = try? JSONDecoder().decode([ProjectInfo].self, from: data) else {
            return
        }

        // Filter out non-existent projects
        recentProjects = projects.filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    /// Save recent projects list
    private func saveRecentProjects() {
        let recentProjectsURL = Self.projectsDirectory.appendingPathComponent(".recent_projects.json")

        if let data = try? JSONEncoder().encode(recentProjects) {
            try? data.write(to: recentProjectsURL)
        }
    }

    /// Add to recent projects
    private func addToRecentProjects(_ info: ProjectInfo) {
        recentProjects.removeAll { $0.url == info.url }
        recentProjects.insert(info, at: 0)

        // Keep the most recent 10 projects
        if recentProjects.count > 10 {
            recentProjects = Array(recentProjects.prefix(10))
        }

        saveRecentProjects()
    }

    /// Remove from recent projects
    func removeFromRecentProjects(url: URL) {
        recentProjects.removeAll { $0.url == url }
        saveRecentProjects()
    }

    /// Clear recent projects
    func clearRecentProjects() {
        recentProjects = []
        saveRecentProjects()
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

    /// Built-in templates
    static let builtInTemplates: [ProjectTemplate] = [
        ProjectTemplate(
            name: "Blank Project",
            description: "Start creating video from scratch",
            settings: ProjectSettings(),
            icon: "doc"
        ),
        ProjectTemplate(
            name: "TikTok/Short Video",
            description: "9:16 portrait, perfect for short videos",
            settings: ProjectSettings(resolution: .vertical1080x1920, frameRate: 30),
            icon: "iphone"
        ),
        ProjectTemplate(
            name: "YouTube",
            description: "16:9 landscape, 1080p",
            settings: ProjectSettings(resolution: .hd1080p, frameRate: 30),
            icon: "play.rectangle"
        ),
        ProjectTemplate(
            name: "4K Cinema",
            description: "4K resolution, 24fps cinematic",
            settings: ProjectSettings(resolution: .uhd4k, frameRate: 24),
            icon: "film"
        ),
        ProjectTemplate(
            name: "Instagram Reels",
            description: "9:16 portrait, perfect for Reels",
            settings: ProjectSettings(resolution: .vertical1080x1920, frameRate: 30),
            icon: "camera"
        )
    ]

    /// Create project from template
    func createFromTemplate(_ template: ProjectTemplate, name: String) -> Project {
        var project = Project(name: name, settings: template.settings)
        return project
    }

    // MARK: - Project Backup

    /// Create project backup
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

    /// Get all backups for project
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
