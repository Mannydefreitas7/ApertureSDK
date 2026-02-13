import Foundation
import AVFoundation

// MARK: - Project Manager

/// Project manager
actor ProjectManager {

    /// Project file extension
    static let projectExtension = "vproj"
    static let shared = ProjectManager()

    /// Projects directory
    static var projectsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let projectsPath = documentsPath.appendingPathComponent("VideoEditor Projects")

        if !FileManager.default.fileExists(atPath: projectsPath.path) {
            try? FileManager.default.createDirectory(at: projectsPath, withIntermediateDirectories: true)
        }
        return projectsPath
    }

    private init() { }

    /// Recent projects
    var recentProjects: [ProjectInfo] = []

    /// Auto-save timer
    private var autoSaveTimer: Timer?

    /// Current project path
    private var currentProjectURL: URL?

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

        // Save thumbnail
         //saveThumbnail(for: project, at: projectDir)
        let project = ProjectInfo(url: targetURL, name: project.name, modifiedAt: Date(), thumbnailPath: nil)

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
    func load(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

       // let projectData = try decoder.decode(ProjectData.self, from: data)

        // Rebuild project
//        var project = Project(
//            id: projectData.id,
//            name: projectData.name,
//            settings: projectData.settings
//        )
//        project.createdAt = projectData.createdAt
//        project.modifiedAt = projectData.modifiedAt

        // Rebuild tracks
        //project.tracks = []
//        for trackData in projectData.tracks {
//            var track = Track(
//                id: trackData.id,
//                name: trackData.name,
//                type: trackData.type
//            )
//            track.isMuted = trackData.isMuted
//            track.isLocked = trackData.isLocked
//            track.isVisible = trackData.isVisible
//            track.volume = trackData.volume
//
//            // Rebuild clips
//            for clipData in trackData.clips {
//                let sourceURL = URL(fileURLWithPath: clipData.sourceURL)
//
//                // Check if file exists
//                guard FileManager.default.fileExists(atPath: sourceURL.path) else {
//                    print("Warning: Cannot find media file \(sourceURL.path)")
//                    continue
//                }
//
//                let asset = AVURLAsset(url: sourceURL)
//                let timeRange = CMTimeRange(
//                    start: CMTime(seconds: clipData.sourceTimeRangeStart, preferredTimescale: 600),
//                    duration: CMTime(seconds: clipData.sourceTimeRangeDuration, preferredTimescale: 600)
//                )
//
//                var clip = Clip(id: clipData.id, type: clipData.type, timeRange: timeRange)
//
//
////                Clip(
////
////                    id: clipData.id,
////                    asset: asset, timeRange: <#ClipTimeRange#>,
////                    sourceURL: sourceURL,
////                    sourceTimeRange: CMTimeRange(
////                        start: CMTime(seconds: clipData.sourceTimeRangeStart, preferredTimescale: 600),
////                        duration: CMTime(seconds: clipData.sourceTimeRangeDuration, preferredTimescale: 600)
////                    ),
////                    startTime: CMTime(seconds: clipData.startTime, preferredTimescale: 600),
////                    type: clipData.type,
////                    name: clipData.name
////                )
//                clip.volume = clipData.volume
//                clip.speed = clipData.speed
//                clip.filter = clipData.filter
//                clip.transform = clipData.transform.toClipTransform()
//
//                track.clips.append(clip)
//            }
//
//         //   project.tracks.append(track)
//        }

        // Rebuild transitions
//        project.transitions = projectData.transitions.map { data in
//            Transition(
//                id: data.id,
//                type: TransitionType(rawValue: data.type) ?? .crossDissolve,
//                duration: CMTime(seconds: data.duration, preferredTimescale: 600),
//                fromClipId: data.fromClipId,
//                toClipId: data.toClipId
//            )
//        }

        // Rebuild global filter
    //    project.globalFilter = projectData.globalFilter

        currentProjectURL = url

        // Update recent projects
//        addToRecentProjects(ProjectInfo(
//            url: url,
//            name: project.name,
//            modifiedAt: Date()
//        ))

     //   return project
    }

    // MARK: - Auto Save

    /// Enable auto save
    func enableAutoSave(project: Project, interval: TimeInterval = 60) {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // Enter an async context within the synchronous callback
            Task {
              try await self?.save(project: project)
            }
        }
        // Ensure the timer runs on the main run loop in a common mode
        RunLoop.main.add(autoSaveTimer!, forMode: .common)
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
        var project = Project(name: name)
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



