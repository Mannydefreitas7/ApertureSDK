import Foundation

/// Represents a video editing project - serializable and AVFoundation-independent
public struct Project: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var canvasSize: CanvasSize
    public var fps: Double
    public var audioSampleRate: Double
    public var tracks: [Track]
    public var createdAt: Date
    public var modifiedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        canvasSize: CanvasSize = .hd1080p,
        fps: Double = 30,
        audioSampleRate: Double = 44100,
        tracks: [Track] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.canvasSize = canvasSize
        self.fps = fps
        self.audioSampleRate = audioSampleRate
        self.tracks = tracks
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    /// Add a track to the project
    public mutating func addTrack(_ track: Track) {
        tracks.append(track)
        modifiedAt = Date()
    }
    
    /// Remove a track by ID
    public mutating func removeTrack(id: UUID) {
        tracks.removeAll { $0.id == id }
        modifiedAt = Date()
    }
    
    /// Total duration of the project in seconds
    public var totalDuration: Double {
        tracks.map { $0.totalDuration }.max() ?? 0
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
}
