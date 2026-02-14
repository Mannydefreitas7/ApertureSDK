//
//  Clip+Extension.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation

extension Clip {

    /// Create a compound clip from a list of clips
    ///
    /// Groups the provided clips into a single compound clip whose `subTimeline`
    /// contains one track holding the clips. The compound clip's `timeRange`
    /// duration equals the sum of the grouped clips' durations.
    ///
    /// - Parameters:
    ///   - clips: Clips to group.
    ///   - trackType: Track type for the inner track (default `.video`).
    /// - Returns: A compound clip, or `nil` if `clips` is empty.
    public static func makeCompound(
        from clips: [Clip],
        trackType: Track.TrackType = .video
    ) -> Clip? {
        guard !clips.isEmpty else { return nil }

        let totalDuration = clips.reduce(0) { $0 + $1.timeRange.duration }
        let innerTrack = Track(type: trackType, clips: clips)

        return Clip(
            type: .compound,
            timeRange: ClipTimeRange(start: 0, duration: totalDuration),
            subTimeline: [innerTrack]
        )
    }

    /// Trim the clip to new start/duration
    public mutating func trim(start: Double, duration: Double) {
        self.timeRange = ClipTimeRange(start: start, duration: duration)
    }

    /// Split the clip at a given time offset from clip start, returning two clips
    public func split(at offset: Double) -> (Clip, Clip)? {
        guard offset > 0 && offset < timeRange.duration else { return nil }

        var first = self
        first.id = UUID()
        first.timeRange = ClipTimeRange(start: timeRange.start, duration: offset)

        var second = self
        second.id = UUID()
        second.timeRange = ClipTimeRange(start: timeRange.start + offset, duration: timeRange.duration - offset)

        return (first, second)
    }

    /// Total duration of the sub-timeline (for compound clips)
    public var subTimelineDuration: Double {
        subTimeline?.map { $0.totalDuration }.max() ?? 0
    }

}
