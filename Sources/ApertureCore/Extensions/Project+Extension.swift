//
//  Project+Extension.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation
import AVFoundation

extension Project {
        /// 添加轨道
    mutating func addTrack(type: TrackType) {
        let count = tracks.filter { $0.type == type }.count + 1
        let name: String
        switch type {
            case .video: name = "视频轨道 \(count)"
            case .audio: name = "音频轨道 \(count)"
            case .subtitle: name = "字幕轨道 \(count)"
            case .effect: name = "特效轨道 \(count)"
        }
        tracks.append(Track(name: name, type: type))
        modifiedAt = Date()
    }

        /// 删除轨道
    mutating func removeTrack(id: UUID) {
        tracks.removeAll { $0.id == id }
        modifiedAt = Date()
    }

        /// 查找包含指定片段的轨道
    func track(containingClip clipId: UUID) -> Track? {
        tracks.first { track in
            track.clips.contains { $0.id == clipId }
        }
    }

        /// 更新轨道
    mutating func updateTrack(_ track: Track) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index] = track
            modifiedAt = Date()
        }
    }
}

    // MARK: - 文字操作
extension Project {

        /// Add a track to the project
    public mutating func addTrack(_ track: Track) {
        tracks.append(track)
        modifiedAt = Date()
    }

        /// Total duration of the project in seconds
    public var totalDuration: Double {
        tracks.map { $0.totalDuration }.max() ?? 0
    }

        /// Group clips within a track into a compound clip.
        ///
        /// - Parameters:
        ///   - clipIDs: IDs of clips to group.
        ///   - trackID: ID of the track containing the clips.
        /// - Returns: The compound clip, or `nil` if the track was not found or
        ///   fewer than two matching clips exist.
    @discardableResult
    public mutating func groupClips(ids clipIDs: Set<UUID>, inTrack trackID: UUID) -> Clip? {
        guard let trackIndex = tracks.firstIndex(where: { $0.id == trackID }) else {
            return nil
        }
        let result = tracks[trackIndex].groupClips(ids: clipIDs)
        if result != nil { modifiedAt = Date() }
        return result
    }

        /// Ungroup a compound clip within a track, replacing it with its inner clips.
        ///
        /// - Parameters:
        ///   - clipID: ID of the compound clip to ungroup.
        ///   - trackID: ID of the track containing the compound clip.
        /// - Returns: The inner clips, or `nil` if the track or compound clip was not found.
    @discardableResult
    public mutating func ungroupCompoundClip(id clipID: UUID, inTrack trackID: UUID) -> [Clip]? {
        guard let trackIndex = tracks.firstIndex(where: { $0.id == trackID }) else {
            return nil
        }
        let result = tracks[trackIndex].ungroupCompoundClip(id: clipID)
        if result != nil { modifiedAt = Date() }
        return result
    }


        /// Serialize project to JSON data
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

        /// Deserialize project from JSON data
    public static func fromJSON(_ data: Data) throws -> Project {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Project.self, from: data)
    }
        /// 添加文字覆盖层
    mutating func addTextOverlay(_ overlay: TextOverlay) {
        textOverlays.append(overlay)
        modifiedAt = Date()
    }

        /// 删除文字覆盖层
    mutating func removeTextOverlay(id: UUID) {
        textOverlays.removeAll { $0.id == id }
        modifiedAt = Date()
    }

        /// 更新文字覆盖层
    mutating func updateTextOverlay(_ overlay: TextOverlay) {
        if let index = textOverlays.firstIndex(where: { $0.id == overlay.id }) {
            textOverlays[index] = overlay
            modifiedAt = Date()
        }
    }

        /// 获取指定时间点的文字覆盖层
    func textOverlays(at time: CMTime) -> [TextOverlay] {
        textOverlays.filter { overlay in
            CMTimeRangeContainsTime(overlay.timeRange, time: time)
        }
    }
}

    // MARK: - 转场操作
extension Project {
        /// 添加转场效果
    mutating func addTransition(_ transition: Transition) {
        transitions.append(transition)
        modifiedAt = Date()
    }

        /// 删除转场效果
    mutating func removeTransition(id: UUID) {
        transitions.removeAll { $0.id == id }
        modifiedAt = Date()
    }

        /// 更新转场效果
    mutating func updateTransition(_ transition: Transition) {
        if let index = transitions.firstIndex(where: { $0.id == transition.id }) {
            transitions[index] = transition
            modifiedAt = Date()
        }
    }

        /// 获取两个片段之间的转场
    func transition(from clipId: UUID, to nextClipId: UUID) -> Transition? {
        transitions.first { $0.fromClipId == clipId && $0.toClipId == nextClipId }
    }
}

    // MARK: - 滤镜操作
extension Project {
        /// 设置全局滤镜
    mutating func setGlobalFilter(_ filter: VideoFilter?) {
        globalFilter = filter
        modifiedAt = Date()
    }
}
