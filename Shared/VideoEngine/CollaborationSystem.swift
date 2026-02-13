import Foundation
import CloudKit
import Combine
import AVFoundation

// MARK: - 8. 协作功能

// MARK: - 云端同步

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
        case idle = "空闲"
        case syncing = "同步中"
        case success = "同步成功"
        case failed = "同步失败"
        case conflict = "冲突"
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

    // 同步项目到云端
    func syncProject(_ project: Project) async throws {
        guard isCloudAvailable else {
            throw SyncError.cloudUnavailable
        }

        isSyncing = true
        syncStatus = .syncing
        defer {
            isSyncing = false
        }

        // 将项目转换为 CKRecord
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

    // 从云端获取项目
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

    // 删除云端项目
    func deleteProject(_ project: Project) async throws {
        let recordID = CKRecord.ID(recordName: project.id.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    // 解决冲突
    func resolveConflict(local: Project, remote: Project, resolution: ConflictResolution) -> Project {
        switch resolution {
        case .keepLocal:
            return local
        case .keepRemote:
            return remote
        case .merge:
            // 合并两个项目（简化实现）
            return local
        }
    }

    /// 用于云端同步的项目元数据
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

        // 只保存项目元数据，不保存完整项目（包含非Codable的AVAsset）
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

        // 创建新项目并填充元数据
        var project = Project(name: metadata.name, settings: metadata.settings)
        // 注意：实际实现需要从本地存储恢复完整项目数据
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

// MARK: - 多人协作

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
        case owner = "所有者"
        case editor = "编辑者"
        case viewer = "查看者"
        case commenter = "评论者"

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

    // 开始协作会话
    func startSession(for project: Project) async throws -> String {
        let sessionId = UUID().uuidString
        self.sessionId = sessionId
        isCollaborating = true

        // 连接到协作服务器
        // 简化实现

        return sessionId
    }

    // 结束协作会话
    func endSession() {
        sessionId = nil
        isCollaborating = false
        collaborators.removeAll()
    }

    // 邀请协作者
    func invite(email: String, role: CollaboratorRole, for project: Project) async throws {
        // 发送邀请邮件
        // 简化实现
    }

    // 接受邀请
    func acceptInvitation(_ invitation: Invitation) async throws {
        pendingInvitations.removeAll { $0.id == invitation.id }
        // 加入协作会话
    }

    // 拒绝邀请
    func declineInvitation(_ invitation: Invitation) {
        pendingInvitations.removeAll { $0.id == invitation.id }
    }

    // 移除协作者
    func removeCollaborator(_ collaborator: Collaborator) async throws {
        collaborators.removeAll { $0.id == collaborator.id }
    }

    // 更改协作者角色
    func changeRole(for collaborator: Collaborator, to newRole: CollaboratorRole) async throws {
        if let index = collaborators.firstIndex(where: { $0.id == collaborator.id }) {
            collaborators[index].role = newRole
        }
    }

    // 广播操作
    func broadcastOperation(_ operation: EditOperation) {
        // 通过 WebSocket 发送操作
    }

    // 接收远程操作
    func receiveOperation(_ operation: EditOperation) {
        // 应用远程操作
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

// MARK: - 评论和标注

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
        var position: CGPoint?  // 画面上的位置（可选）

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
            case marker = "标记"
            case todo = "待办"
            case issue = "问题"
            case approved = "已批准"
            case rejected = "已拒绝"
        }
    }

    private init() {}

    // 添加评论
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

    // 回复评论
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

    // 解决评论
    func resolveComment(_ commentId: UUID) {
        guard let index = comments.firstIndex(where: { $0.id == commentId }) else { return }
        comments[index].isResolved = true
    }

    // 删除评论
    func deleteComment(_ commentId: UUID) {
        comments.removeAll { $0.id == commentId }
    }

    // 添加标注
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

    // 获取某时间点的评论
    func commentsAt(time: CMTime, tolerance: CMTime = CMTime(seconds: 1, preferredTimescale: 600)) -> [TimelineComment] {
        comments.filter { comment in
            let diff = CMTimeAbsoluteValue(CMTimeSubtract(comment.time, time))
            return CMTimeCompare(diff, tolerance) <= 0
        }
    }

    // 导出评论
    func exportComments() -> String {
        var result = "# 评论列表\n\n"

        for comment in comments.sorted(by: { CMTimeCompare($0.time, $1.time) < 0 }) {
            let timeStr = formatTime(comment.time)
            result += "## [\(timeStr)] \(comment.author)\n"
            result += "\(comment.text)\n"

            if comment.isResolved {
                result += "*已解决*\n"
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

// MARK: - 版本历史

class VersionHistoryManager: ObservableObject {
    static let shared = VersionHistoryManager()

    @Published var versions: [ProjectVersion] = []
    @Published var currentVersionId: UUID?
    @Published var isAutoSaveEnabled = true
    @Published var autoSaveInterval: TimeInterval = 300  // 5分钟

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
            createdBy: String = "用户",
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

    // 创建新版本
    func createVersion(for project: Project, name: String = "", description: String = "", isAutoSave: Bool = false) throws {
        // 只保存项目元数据
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
            name: name.isEmpty ? "版本 \(versionNumber)" : name,
            description: description,
            data: data,
            isAutoSave: isAutoSave
        )

        versions.append(version)
        currentVersionId = version.id

        // 清理旧的自动保存版本（保留最近5个）
        cleanupAutoSaves(for: project.id)
    }

    // 恢复到指定版本
    func restoreVersion(_ version: ProjectVersion) throws -> Project {
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(CloudSyncManager.ProjectMetadata.self, from: version.data)
        currentVersionId = version.id

        // 从元数据创建项目（实际实现需要从本地存储恢复完整数据）
        let project = Project(name: metadata.name, settings: metadata.settings)
        return project
    }

    // 比较两个版本
    func compareVersions(_ version1: ProjectVersion, _ version2: ProjectVersion) -> VersionDiff {
        // 简化实现：返回基本差异信息
        return VersionDiff(
            addedClips: 0,
            removedClips: 0,
            modifiedClips: 0,
            addedEffects: 0,
            removedEffects: 0
        )
    }

    // 删除版本
    func deleteVersion(_ version: ProjectVersion) {
        versions.removeAll { $0.id == version.id }
    }

    // 获取项目的所有版本
    func versionsFor(projectId: UUID) -> [ProjectVersion] {
        versions.filter { $0.projectId == projectId }
            .sorted { $0.versionNumber > $1.versionNumber }
    }

    // 开始自动保存
    func startAutoSave(for project: Project) {
        stopAutoSave()

        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            try? self?.createVersion(for: project, name: "自动保存", isAutoSave: true)
        }
    }

    // 停止自动保存
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
            case view = "仅查看"
            case comment = "可评论"
            case edit = "可编辑"
            case download = "可下载"
        }
    }

    private init() {}

    // 创建分享链接
    func createShareLink(
        for project: Project,
        accessType: SharedLink.AccessType,
        expiresIn: TimeInterval? = nil,
        password: String? = nil
    ) async throws -> SharedLink {
        // 上传项目并生成链接
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

    // 撤销分享链接
    func revokeShareLink(_ link: SharedLink) {
        sharedLinks.removeAll { $0.id == link.id }
    }

    // 更新分享设置
    func updateShareLink(_ link: SharedLink, accessType: SharedLink.AccessType?, password: String?) {
        guard let index = sharedLinks.firstIndex(where: { $0.id == link.id }) else { return }

        if let accessType = accessType {
            sharedLinks[index].accessType = accessType
        }
        sharedLinks[index].password = password
    }
}

// MARK: - 团队工作区

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
        case owner = "所有者"
        case admin = "管理员"
        case member = "成员"
        case guest = "访客"
    }

    struct WorkspaceSettings: Codable {
        var allowGuestAccess: Bool = false
        var requireApproval: Bool = true
        var defaultProjectAccess: CollaborationManager.CollaboratorRole = .viewer
        var storageLimit: Int64 = 10_737_418_240  // 10GB
    }

    private init() {}

    // 创建工作区
    func createWorkspace(name: String, description: String = "") -> TeamWorkspace {
        let workspace = TeamWorkspace(
            id: UUID(),
            name: name,
            description: description,
            createdAt: Date(),
            ownerId: UUID(),  // 当前用户ID
            projectIds: [],
            settings: WorkspaceSettings()
        )
        workspaces.append(workspace)
        return workspace
    }

    // 切换工作区
    func switchWorkspace(_ workspace: TeamWorkspace) {
        currentWorkspace = workspace
        // 加载工作区成员和项目
    }

    // 添加成员
    func addMember(email: String, role: TeamRole) async throws {
        // 发送邀请
    }

    // 移除成员
    func removeMember(_ member: TeamMember) {
        members.removeAll { $0.id == member.id }
    }

    // 添加项目到工作区
    func addProject(_ project: Project) {
        currentWorkspace?.projectIds.append(project.id)
    }

    // 从工作区移除项目
    func removeProject(_ projectId: UUID) {
        currentWorkspace?.projectIds.removeAll { $0 == projectId }
    }
}
