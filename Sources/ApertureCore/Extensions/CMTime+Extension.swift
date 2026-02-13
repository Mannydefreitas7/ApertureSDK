//
//  CMTime+Extension.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import AVFoundation
    // MARK: - CMTime Codable Extension

extension CMTime: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case value
        case timescale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Int64.self, forKey: .value)
        let timescale = try container.decode(Int32.self, forKey: .timescale)
        self.init(value: value, timescale: timescale)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(timescale, forKey: .timescale)
    }
}


extension CMTimeRange: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case start
        case duration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let start = try container.decode(CMTime.self, forKey: .start)
        let duration = try container.decode(CMTime.self, forKey: .duration)
        self.init(start: start, duration: duration)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(start, forKey: .start)
        try container.encode(duration, forKey: .duration)
    }
}
