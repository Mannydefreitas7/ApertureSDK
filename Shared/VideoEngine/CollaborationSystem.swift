import Foundation
import CloudKit
import Combine
import AVFoundation

// MARK: - 8. Collaboration Features

// MARK: - Cloud Sync

class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()

    @Published var isSyncing = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0
    @Published var isCloudAvailable = false

    private let container = CKContainer.default()
    private let privateDatabase: CKDatabase
    private var cancellables = Set<AnyCancellable>()

    enum SyncStatus: String {
        case idle = "Idle"
        case syncing = "Syncing"
        case success = "Success"
        case failed = "Failed"
        case conflict = "Conflict"
    }

    private init() {
        privateDatabase = container.privateCloudDatabase
        checkCloudStatus()
    }

    private func checkCloudStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.isCloudAvailable = status == .available
            }
        }
    }

    // Sync project to cloud
    func syncProject(_ project: Project) async throws {
        guard isCloudAvailable else {
            throw SyncError.cloudUnavailable
        }

        isSyncing = true
        syncStatus = .syncing
        defer {
            isSyncing = false
        }

        // Convert project to CKRecord
        let record = try projectToRecord(project)

        do {
            _ = try await privateDatabase.save(record)
            syncStatus = .success
            lastSyncDate = Date()
        } catch {
            syncStatus = .failed
            throw error
        }
    }

    // Fetch projects from cloud
    func fetchProjects() async throws -> [Project] {
        guard isCloudAvailable else {
            throw SyncError.cloudUnavailable
        }

        let query = CKQuery(recordType: "Project", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]

        let results = try await privateDatabase.records(matching: query)

        var projects: [Project] = []
        for (_, result) in results.matchResults {
            if let record = try? result.get() {
                if let project = recordToProject(record) {
                    projects.append(project)
                }
            }
        }

        return projects
    }

    // Delete project from cloud
    func deleteProject(_ project: Project) async throws {
        let recordID = CKRecord.ID(recordName: project.id.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    // Resolve conflicts
    func resolveConflict(local: Project, remote: Project, resolution: ConflictResolution) -> Project {
        switch resolution {
        case .keepLocal:
            return local
        case .keepRemote:
            return remote
        case .merge:
            // Merge two projects (simplified implementation)
            return local
        }
    }

    /// Project metadata for cloud sync
    struct ProjectMetadata: Codable {
        let id: UUID
        var name: String
        var createdAt: Date
        var modifiedAt: Date
        var settings: ProjectSettings
    }

    private func projectToRecord(_ project: Project) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: project.id.uuidString)
        let record = CKRecord(recordType: "Project", recordID: recordID)

        // Only save project metadata, not the complete project (contains non-Codable AVAsset)
        let metadata = ProjectMetadata(
            id: project.id,
            name: project.name,
            createdAt: project.createdAt,
            modifiedAt: project.modifiedAt,
            settings: project.settings
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)

        record["name"] = project.name
        record["data"] = data
        record["modificationDate"] = Date()

        return record
    }

    private func recordToProject(_ record: CKRecord) -> Project? {
        guard let data = record["data"] as? Data else { return nil }

        let decoder = JSONDecoder()
        guard let metadata = try? decoder.decode(ProjectMetadata.self, from: data) else { return nil }

        // Create new project and populate metadata
        var project = Project(name: metadata.name, settings: metadata.settings)
        // Note: actual implementation would restore complete project data from local storage
        return project
    }

    enum SyncError: Error {
        case cloudUnavailable
        case encodingFailed
        case decodingFailed
    }

    enum ConflictResolution {
        case keepLocal
        case keepRemote
        case merge
    }
}

// MARK: - Multi-user Collaboration

class CollaborationManager: ObservableObject {
    static let shared = CollaborationManager()

    @Published var isCollaborating = false
    @Published var collaborators: [Collaborator] = []
    @Published var pendingInvitations: [Invitation] = []
    @Published var sessionId: String?

    struct Collaborator: Identifiable {
        let id: UUID
        var name: String
        var email: String
        var avatarURL: URL?
        var role: CollaboratorRole
        var isOnline: Bool
        var cursorPosition: CMTime?
        var selectedClipId: UUID?
    }

    enum CollaboratorRole: String, Codable {
        case owner = "Owner"
        case editor = "Editor"
        case viewer = "Viewer"
        case commenter = "Commenter"

        var canEdit: Bool {
            self == .owner || self == .editor
        }

        var canComment: Bool {
            self != .viewer
        }
    }

    struct Invitation: Identifiable {
        let id: UUID
        var projectId: UUID
        var projectName: String
        var inviterName: String
        var role: CollaboratorRole
        var expiresAt: Date
    }

    private init() {}

    // Start collaboration session
    func startSession(for project: Project) async throws -> String {
        let sessionId = UUID().uuidString
        self.sessionId = sessionId
        isCollaborating = true

        // Connect to collaboration server
        // Simplified implementation

        return sessionId
    }

    // End collaboration session
    func endSession() {
        sessionId = nil
        isCollaborating = false
        collaborators.removeAll()
    }

    // Invite collaborator
    func invite(email: String, role: CollaboratorRole, for project: Project) async throws {
        // Send invitation email
        // Simplified implementation
    }

    // Accept invitation
    func acceptInvitation(_ invitation: Invitation) async throws {
        pendingInvitations.removeAll { $0.id == invitation.id }
        // Join collaboration session
    }

    // Decline invitation
    func declineInvitation(_ invitation: Invitation) {
        pendingInvitations.removeAll { $0.id == invitation.id }
    }

    // Remove collaborator
    func removeCollaborator(_ collaborator: Collaborator) async throws {
        collaborators.removeAll { $0.id == collaborator.id }
    }

    // Update collaborator role
    func changeRole(for collaborator: Collaborator, to newRole: CollaboratorRole) async throws {
        if let index = collaborators.firstIndex(where: { $0.id == collaborator.id }) {
            collaborators[index].role = newRole
        }
    }

    // Broadcast operation
    func broadcastOperation(_ operation: EditOperation) {
        // Send operation via WebSocket
    }

    // Receive remote operation
    func receiveOperation(_ operation: EditOperation) {
        // Apply remote operation
    }

    struct EditOperation: Codable {
        var type: OperationType
        var userId: UUID
        var timestamp: Date
        var data: Data

        enum OperationType: String, Codable {
            case addClip
            case removeClip
            case moveClip
            case trimClip
            case addEffect
            case removeEffect
            case addText
            case modifyText
            case undo
            case redo
        }
    }
}

// MARK: - Comments and Annotations

class CommentManager: ObservableObject {
    static let shared = CommentManager()

    @Published var comments: [TimelineComment] = []
    @Published var annotations: [TimelineAnnotation] = []
    @Published var selectedComment: TimelineComment?

    struct TimelineComment: Identifiable, Codable {
        let id: UUID
        var time: CMTime
        var duration: CMTime?
        var text: String
        var author: String
        var authorId: UUID
        var createdAt: Date
        var replies: [CommentReply]
        var isResolved: Bool
        var position: CGPoint?  // Position on screen (optional)

        init(
            id: UUID = UUID(),
            time: CMTime,
            duration: CMTime? = nil,
            text: String,
            author: String,
            authorId: UUID,
            createdAt: Date = Date(),
            replies: [CommentReply] = [],
            isResolved: Bool = false,
            position: CGPoint? = nil
        ) {
            self.id = id
            self.time = time
            self.duration = duration
            self.text = text
            self.author = author
            self.authorId = authorId
            self.createdAt = createdAt
            self.replies = replies
            self.isResolved = isResolved
            self.position = position
        }
    }

    struct CommentReply: Identifiable, Codable {
        let id: UUID
        var text: String
        var author: String
        var authorId: UUID
        var createdAt: Date
    }

    struct TimelineAnnotation: Identifiable, Codable {
        let id: UUID
        var type: AnnotationType
        var time: CMTime
        var duration: CMTime?
        var color: CodableColor
        var label: String

        enum AnnotationType: String, Codable {
            case marker = "Marker"
            case todo = "To Do"
            case issue = "Issue"
            case approved = "Approved"
            case rejected = "Rejected"
        }
    }

    private init() {}

    // Add comment
    func addComment(at time: CMTime, text: String, author: String, authorId: UUID, position: CGPoint? = nil) {
        let comment = TimelineComment(
            time: time,
            text: text,
            author: author,
            authorId: authorId,
            position: position
        )
        comments.append(comment)
    }

    // Reply to comment
    func replyToComment(_ commentId: UUID, text: String, author: String, authorId: UUID) {
        guard let index = comments.firstIndex(where: { $0.id == commentId }) else { return }

        let reply = CommentReply(
            id: UUID(),
            text: text,
            author: author,
            authorId: authorId,
            createdAt: Date()
        )
        comments[index].replies.append(reply)
    }

    // Resolve comment
    func resolveComment(_ commentId: UUID) {
        guard let index = comments.firstIndex(where: { $0.id == commentId }) else { return }
        comments[index].isResolved = true
    }

    // Delete comment
    func deleteComment(_ commentId: UUID) {
        comments.removeAll { $0.id == commentId }
    }

    // Add annotation
    func addAnnotation(type: TimelineAnnotation.AnnotationType, at time: CMTime, label: String, color: CodableColor) {
        let annotation = TimelineAnnotation(
            id: UUID(),
            type: type,
            time: time,
            color: color,
            label: label
        )
        annotations.append(annotation)
    }

    // Get comments at time point
    func commentsAt(time: CMTime, tolerance: CMTime = CMTime(seconds: 1, preferredTimescale: 600)) -> [TimelineComment] {
        comments.filter { comment in
            let diff = CMTimeAbsoluteValue(CMTimeSubtract(comment.time, time))
            return CMTimeCompare(diff, tolerance) <= 0
        }
    }

    // Export comments
    func exportComments() -> String {
        var result = "# Comment List\n\n"

        for comment in comments.sorted(by: { CMTimeCompare($0.time, $1.time) < 0 }) {
            let timeStr = formatTime(comment.time)
            result += "## [\(timeStr)] \(comment.author)\n"
            result += "\(comment.text)\n"

            if comment.isResolved {
                result += "*Resolved*\n"
            }

            for reply in comment.replies {
                result += "  - \(reply.author): \(reply.text)\n"
            }

            result += "\n"
        }

        return result
    }

    private func formatTime(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Version History

class VersionHistoryManager: ObservableObject {
    static let shared = VersionHistoryManager()

    @Published var versions: [ProjectVersion] = []
    @Published var currentVersionId: UUID?
    @Published var isAutoSaveEnabled = true
    @Published var autoSaveInterval: TimeInterval = 300  // 5 minutes

    private var autoSaveTimer: Timer?

    struct ProjectVersion: Identifiable, Codable {
        let id: UUID
        var projectId: UUID
        var versionNumber: Int
        var name: String
        var description: String
        var createdAt: Date
        var createdBy: String
        var data: Data
        var thumbnail: Data?
        var isAutoSave: Bool

        init(
            id: UUID = UUID(),
            projectId: UUID,
            versionNumber: Int,
            name: String = "",
            description: String = "",
            createdAt: Date = Date(),
            createdBy: String = "User",
            data: Data,
            thumbnail: Data? = nil,
            isAutoSave: Bool = false
        ) {
            self.id = id
            self.projectId = projectId
            self.versionNumber = versionNumber
            self.name = name
            self.description = description
            self.createdAt = createdAt
            self.createdBy = createdBy
            self.data = data
            self.thumbnail = thumbnail
            self.isAutoSave = isAutoSave
        }
    }

    private init() {}

    // Create new version
    func createVersion(for project: Project, name: String = "", description: String = "", isAutoSave: Bool = false) throws {
        // Only save project metadata
        let metadata = CloudSyncManager.ProjectMetadata(
            id: project.id,
            name: project.name,
            createdAt: project.createdAt,
            modifiedAt: project.modifiedAt,
            settings: project.settings
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)

        let versionNumber = (versions.filter { $0.projectId == project.id }.map { $0.versionNumber }.max() ?? 0) + 1

        let version = ProjectVersion(
            projectId: project.id,
            versionNumber: versionNumber,
            name: name.isEmpty ? "Version \(versionNumber)" : name,
            description: description,
            data: data,
            isAutoSave: isAutoSave
        )

        versions.append(version)
        currentVersionId = version.id

        // Clean up old auto-save versions (keep latest 5)
        cleanupAutoSaves(for: project.id)
    }

    // Restore to specified version
    func restoreVersion(_ version: ProjectVersion) throws -> Project {
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(CloudSyncManager.ProjectMetadata.self, from: version.data)
        currentVersionId = version.id

        // Create project from metadata (actual implementation would restore complete data from local storage)
        let project = Project(name: metadata.name, settings: metadata.settings)
        return project
    }

    // Compare two versions
    func compareVersions(_ version1: ProjectVersion, _ version2: ProjectVersion) -> VersionDiff {
        // Simplified implementation: return basic difference information
        return VersionDiff(
            addedClips: 0,
            removedClips: 0,
            modifiedClips: 0,
            addedEffects: 0,
            removedEffects: 0
        )
    }

    // Delete version
    func deleteVersion(_ version: ProjectVersion) {
        versions.removeAll { $0.id == version.id }
    }

    // Get all versions for project
    func versionsFor(projectId: UUID) -> [ProjectVersion] {
        versions.filter { $0.projectId == projectId }
            .sorted { $0.versionNumber > $1.versionNumber }
    }

    // Start auto-save
    func startAutoSave(for project: Project) {
        stopAutoSave()

        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            try? self?.createVersion(for: project, name: "Auto Save", isAutoSave: true)
        }
    }

    // Stop auto-save
    func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    // 清理旧的自动保存
    private func cleanupAutoSaves(for projectId: UUID, keepCount: Int = 5) {
        let autoSaves = versions
            .filter { $0.projectId == projectId && $0.isAutoSave }
            .sorted { $0.createdAt > $1.createdAt }

        if autoSaves.count > keepCount {
            let toDelete = autoSaves.dropFirst(keepCount)
            for version in toDelete {
                deleteVersion(version)
            }
        }
    }

    struct VersionDiff {
        var addedClips: Int
        var removedClips: Int
        var modifiedClips: Int
        var addedEffects: Int
        var removedEffects: Int

        var description: String {
            var parts: [String] = []
            if addedClips > 0 { parts.append("添加 \(addedClips) 个片段") }
            if removedClips > 0 { parts.append("删除 \(removedClips) 个片段") }
            if modifiedClips > 0 { parts.append("修改 \(modifiedClips) 个片段") }
            if addedEffects > 0 { parts.append("添加 \(addedEffects) 个效果") }
            if removedEffects > 0 { parts.append("删除 \(removedEffects) 个效果") }
            return parts.isEmpty ? "无变化" : parts.joined(separator: ", ")
        }
    }
}

// MARK: - 项目分享

class ProjectShareManager: ObservableObject {
    static let shared = ProjectShareManager()

    @Published var sharedLinks: [SharedLink] = []

    struct SharedLink: Identifiable, Codable {
        let id: UUID
        var projectId: UUID
        var url: URL
        var expiresAt: Date?
        var accessType: AccessType
        var password: String?
        var viewCount: Int
        var createdAt: Date

        enum AccessType: String, Codable {
            case view = "View Only"
            case comment = "Can Comment"
            case edit = "Can Edit"
            case download = "Can Download"
        }
    }

    private init() {}

    // Create share link
    func createShareLink(
        for project: Project,
        accessType: SharedLink.AccessType,
        expiresIn: TimeInterval? = nil,
        password: String? = nil
    ) async throws -> SharedLink {
        // Upload project and generate link
        let linkId = UUID()
        let url = URL(string: "https://videoeditor.app/share/\(linkId.uuidString)")!

        let link = SharedLink(
            id: linkId,
            projectId: project.id,
            url: url,
            expiresAt: expiresIn.map { Date().addingTimeInterval($0) },
            accessType: accessType,
            password: password,
            viewCount: 0,
            createdAt: Date()
        )

        sharedLinks.append(link)
        return link
    }

    // Revoke share link
    func revokeShareLink(_ link: SharedLink) {
        sharedLinks.removeAll { $0.id == link.id }
    }

    // Update share settings
    func updateShareLink(_ link: SharedLink, accessType: SharedLink.AccessType?, password: String?) {
        guard let index = sharedLinks.firstIndex(where: { $0.id == link.id }) else { return }

        if let accessType = accessType {
            sharedLinks[index].accessType = accessType
        }
        sharedLinks[index].password = password
    }
}

// MARK: - Team Workspace

class TeamWorkspaceManager: ObservableObject {
    static let shared = TeamWorkspaceManager()

    @Published var currentWorkspace: TeamWorkspace?
    @Published var workspaces: [TeamWorkspace] = []
    @Published var members: [TeamMember] = []

    struct TeamWorkspace: Identifiable, Codable {
        let id: UUID
        var name: String
        var description: String
        var createdAt: Date
        var ownerId: UUID
        var projectIds: [UUID]
        var settings: WorkspaceSettings
    }

    struct TeamMember: Identifiable, Codable {
        let id: UUID
        var userId: UUID
        var name: String
        var email: String
        var role: TeamRole
        var joinedAt: Date
        var lastActiveAt: Date?
    }

    enum TeamRole: String, Codable {
        case owner = "Owner"
        case admin = "Admin"
        case member = "Member"
        case guest = "Guest"
    }

    struct WorkspaceSettings: Codable {
        var allowGuestAccess: Bool = false
        var requireApproval: Bool = true
        var defaultProjectAccess: CollaborationManager.CollaboratorRole = .viewer
        var storageLimit: Int64 = 10_737_418_240  // 10GB
    }

    private init() {}

    // Create workspace
    func createWorkspace(name: String, description: String = "") -> TeamWorkspace {
        let workspace = TeamWorkspace(
            id: UUID(),
            name: name,
            description: description,
            createdAt: Date(),
            ownerId: UUID(),  // Current user ID
            projectIds: [],
            settings: WorkspaceSettings()
        )
        workspaces.append(workspace)
        return workspace
    }

    // Switch workspace
    func switchWorkspace(_ workspace: TeamWorkspace) {
        currentWorkspace = workspace
        // Load workspace members and projects
    }

    // Add member
    func addMember(email: String, role: TeamRole) async throws {
        // Send invitation
    }

    // Remove member
    func removeMember(_ member: TeamMember) {
        members.removeAll { $0.id == member.id }
    }

    // Add project to workspace
    func addProject(_ project: Project) {
        currentWorkspace?.projectIds.append(project.id)
    }

    // Remove project from workspace
    func removeProject(_ projectId: UUID) {
        currentWorkspace?.projectIds.removeAll { $0 == projectId }
    }
}
