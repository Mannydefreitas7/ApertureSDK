import Foundation
import AVFoundation
import Accelerate

/// Audio Engine - Handles audio waveforms, effects, and analysis
actor AudioEngine {

    // MARK: - Waveform Generation
    static let shared: AudioEngine = .init()

    /// Generate audio waveform data
    static func generateWaveform(
        from asset: AVAsset,
        samplesPerSecond: Int = 10
    ) async throws -> [Float] {
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            return []
        }

        let duration = try await asset.load(.duration)
        let totalSamples = Int(CMTimeGetSeconds(duration)) * samplesPerSecond

        guard let reader = try? AVAssetReader(asset: asset) else {
            return []
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()

        var samples: [Float] = []
        var sampleBuffer: [Int16] = []

        while let buffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(buffer) else { continue }

            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

            if let data = dataPointer {
                let int16Pointer = data.withMemoryRebound(to: Int16.self, capacity: length / 2) { $0 }
                let int16Buffer = UnsafeBufferPointer(start: int16Pointer, count: length / 2)
                sampleBuffer.append(contentsOf: int16Buffer)
            }
        }

        // Downsample to target count
        let samplesPerBucket = max(1, sampleBuffer.count / totalSamples)

        for i in 0..<totalSamples {
            let start = i * samplesPerBucket
            let end = min(start + samplesPerBucket, sampleBuffer.count)

            if start < sampleBuffer.count {
                var maxValue: Int16 = 0
                for j in start..<end {
                    maxValue = max(maxValue, abs(sampleBuffer[j]))
                }
                samples.append(Float(maxValue) / Float(Int16.max))
            }
        }

        return samples
    }

    /// Generate thumbnail waveform (for timeline display)
    static func generateThumbnailWaveform(
        from asset: AVAsset,
        width: Int
    ) async throws -> [Float] {
        return try await generateWaveform(from: asset, samplesPerSecond: width / 5)
    }
}

// MARK: - Audio Effects

/// Audio effect processor
class AudioEffectProcessor {

    /// Audio fade in/fade out
    struct FadeEffect {
        var fadeInDuration: CMTime = .zero
        var fadeOutDuration: CMTime = .zero
        var fadeInCurve: FadeCurve = .linear
        var fadeOutCurve: FadeCurve = .linear
    }

    /// Fade curve type
    enum FadeCurve: String, CaseIterable {
        case linear = "Linear"
        case exponential = "Exponential"
        case logarithmic = "Logarithmic"
        case sCurve = "S-Curve"

        func value(at progress: Float) -> Float {
            switch self {
            case .linear:
                return progress
            case .exponential:
                return progress * progress
            case .logarithmic:
                return sqrt(progress)
            case .sCurve:
                return progress * progress * (3 - 2 * progress)
            }
        }
    }

    /// Apply fade to audio track
    static func applyFade(
        to track: AVMutableCompositionTrack,
        fade: FadeEffect,
        timeRange: CMTimeRange
    ) -> AVMutableAudioMix {
        let audioMix = AVMutableAudioMix()
        let parameters = AVMutableAudioMixInputParameters(track: track)

        var volumeRamps: [(time: CMTime, volume: Float)] = []

        // Fade in
        if fade.fadeInDuration > .zero {
            let fadeInEnd = CMTimeAdd(timeRange.start, fade.fadeInDuration)
            volumeRamps.append((timeRange.start, 0.0))
            volumeRamps.append((fadeInEnd, 1.0))
        }

        // Fade out
        if fade.fadeOutDuration > .zero {
            let fadeOutStart = CMTimeSubtract(timeRange.end, fade.fadeOutDuration)
            volumeRamps.append((fadeOutStart, 1.0))
            volumeRamps.append((timeRange.end, 0.0))
        }

        // Apply volume ramps
        for i in 0..<volumeRamps.count - 1 {
            let start = volumeRamps[i]
            let end = volumeRamps[i + 1]
            parameters.setVolumeRamp(
                fromStartVolume: start.volume,
                toEndVolume: end.volume,
                timeRange: CMTimeRange(start: start.time, end: end.time)
            )
        }

        audioMix.inputParameters = [parameters]
        return audioMix
    }
}

/// Audio equalizer
struct AudioEqualizer: Equatable {
    /// Preset type
    enum Preset: String, CaseIterable {
        case flat = "Flat"
        case bass = "Bass Boost"
        case treble = "Treble Boost"
        case vocal = "Vocal Enhancement"
        case acoustic = "Acoustic"
        case electronic = "Electronic"
        case rock = "Rock"
        case pop = "Pop"
        case jazz = "Jazz"
        case classical = "Classical"
        case custom = "Custom"
    }

    /// Band gains (-12dB to +12dB)
    var bands: [Float] = Array(repeating: 0, count: 10)

    /// Band frequencies
    static let frequencies: [String] = [
        "32Hz", "64Hz", "125Hz", "250Hz", "500Hz",
        "1kHz", "2kHz", "4kHz", "8kHz", "16kHz"
    ]

    /// Apply preset
    mutating func applyPreset(_ preset: Preset) {
        switch preset {
        case .flat:
            bands = Array(repeating: 0, count: 10)
        case .bass:
            bands = [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]
        case .treble:
            bands = [0, 0, 0, 0, 0, 2, 4, 5, 6, 6]
        case .vocal:
            bands = [-2, -1, 0, 2, 4, 4, 3, 2, 0, -1]
        case .acoustic:
            bands = [3, 2, 1, 0, 1, 1, 2, 3, 3, 2]
        case .electronic:
            bands = [4, 3, 0, -2, -1, 1, 0, 2, 4, 5]
        case .rock:
            bands = [4, 3, 2, 0, -1, 0, 2, 3, 4, 4]
        case .pop:
            bands = [-1, 1, 3, 4, 3, 0, -1, -1, 1, 2]
        case .jazz:
            bands = [2, 1, 0, 1, 2, 2, 2, 1, 2, 3]
        case .classical:
            bands = [3, 2, 1, 1, 0, 0, 0, 1, 2, 3]
        case .custom:
            break
        }
    }
}

/// Audio voice changer effect
struct VoiceChanger: Equatable {
    /// Voice type
    enum VoiceType: String, CaseIterable {
        case normal = "Normal"
        case male = "Male"
        case female = "Female"
        case child = "Child"
        case robot = "Robot"
        case monster = "Monster"
        case chipmunk = "Chipmunk"
        case deep = "Deep"

        var pitchShift: Float {
            switch self {
            case .normal: return 0
            case .male: return -200
            case .female: return 300
            case .child: return 500
            case .robot: return 0
            case .monster: return -500
            case .chipmunk: return 800
            case .deep: return -400
            }
        }
    }

    var type: VoiceType = .normal
    var pitchShift: Float = 0  // -1200 to 1200 cents
    var formantShift: Float = 0
}

/// Audio noise reduction
struct NoiseReduction: Equatable {
    /// Noise reduction strength (0-100)
    var strength: Float = 50

    /// Noise type
    enum NoiseType: String, CaseIterable {
        case auto = "Auto"
        case wind = "Wind Noise"
        case hum = "Electrical Hum"
        case hiss = "Hiss"
        case background = "Background Noise"
    }

    var noiseType: NoiseType = .auto
}

// MARK: - Audio Separation

/// Audio separator
class AudioSeparator {

    /// Extract audio from video
    static func separateAudio(
        from videoAsset: AVAsset,
        outputURL: URL
    ) async throws {
        let composition = AVMutableComposition()

        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AudioError.trackCreationFailed
        }

        let sourceAudioTracks = try await videoAsset.loadTracks(withMediaType: .audio)
        guard let sourceTrack = sourceAudioTracks.first else {
            throw AudioError.noAudioTrack
        }

        let duration = try await videoAsset.load(.duration)
        try audioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: sourceTrack,
            at: .zero
        )

        // Export as audio file
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        if exportSession.status != .completed {
            throw exportSession.error ?? AudioError.exportFailed
        }
    }

    /// Merge audio with video
    static func mergeAudio(
        videoAsset: AVAsset,
        audioAsset: AVAsset,
        outputURL: URL,
        videoVolume: Float = 1.0,
        audioVolume: Float = 1.0
    ) async throws {
        let composition = AVMutableComposition()

        // Add video track
        if let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) {
            let sourceVideoTracks = try await videoAsset.loadTracks(withMediaType: .video)
            if let sourceTrack = sourceVideoTracks.first {
                let duration = try await videoAsset.load(.duration)
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: sourceTrack,
                    at: .zero
                )
            }
        }

        // Add original audio track
        let audioMix = AVMutableAudioMix()
        var inputParameters: [AVMutableAudioMixInputParameters] = []

        if let originalAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) {
            let sourceAudioTracks = try await videoAsset.loadTracks(withMediaType: .audio)
            if let sourceTrack = sourceAudioTracks.first {
                let duration = try await videoAsset.load(.duration)
                try originalAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: sourceTrack,
                    at: .zero
                )

                let params = AVMutableAudioMixInputParameters(track: originalAudioTrack)
                params.setVolume(videoVolume, at: .zero)
                inputParameters.append(params)
            }
        }

        // Add new audio track
        if let newAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) {
            let sourceAudioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
            if let sourceTrack = sourceAudioTracks.first {
                let videoDuration = try await videoAsset.load(.duration)
                let audioDuration = try await audioAsset.load(.duration)
                let duration = CMTimeMinimum(videoDuration, audioDuration)

                try newAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: sourceTrack,
                    at: .zero
                )

                let params = AVMutableAudioMixInputParameters(track: newAudioTrack)
                params.setVolume(audioVolume, at: .zero)
                inputParameters.append(params)
            }
        }

        audioMix.inputParameters = inputParameters

        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw AudioError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.audioMix = audioMix

        await exportSession.export()

        if exportSession.status != .completed {
            throw exportSession.error ?? AudioError.exportFailed
        }
    }
}

/// Audio error
enum AudioError: LocalizedError {
    case trackCreationFailed
    case noAudioTrack
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .trackCreationFailed: return "Failed to create audio track"
        case .noAudioTrack: return "No audio track found"
        case .exportFailed: return "Export failed"
        }
    }
}

// MARK: - Volume Keyframes

/// Volume keyframe
struct VolumeKeyframe: Identifiable, Equatable {
    let id: UUID
    var time: CMTime
    var volume: Float  // 0.0 - 2.0
    var curve: AudioEffectProcessor.FadeCurve

    init(
        id: UUID = UUID(),
        time: CMTime,
        volume: Float = 1.0,
        curve: AudioEffectProcessor.FadeCurve = .linear
    ) {
        self.id = id
        self.time = time
        self.volume = volume
        self.curve = curve
    }
}

/// Volume keyframe manager
class VolumeKeyframeManager {
    var keyframes: [VolumeKeyframe] = []

    /// Add keyframe
    func addKeyframe(at time: CMTime, volume: Float) {
        let keyframe = VolumeKeyframe(time: time, volume: volume)
        keyframes.append(keyframe)
        sortKeyframes()
    }

    /// Remove keyframe
    func removeKeyframe(id: UUID) {
        keyframes.removeAll { $0.id == id }
    }

    /// Sort keyframes
    func sortKeyframes() {
        keyframes.sort { CMTimeCompare($0.time, $1.time) < 0 }
    }

    /// Get volume at specified time
    func volume(at time: CMTime) -> Float {
        guard !keyframes.isEmpty else { return 1.0 }

        // Find previous and next keyframes
        var prevKeyframe: VolumeKeyframe?
        var nextKeyframe: VolumeKeyframe?

        for keyframe in keyframes {
            if CMTimeCompare(keyframe.time, time) <= 0 {
                prevKeyframe = keyframe
            } else {
                nextKeyframe = keyframe
                break
            }
        }

        // If before all keyframes
        if prevKeyframe == nil {
            return nextKeyframe?.volume ?? 1.0
        }

        // If after all keyframes
        if nextKeyframe == nil {
            return prevKeyframe?.volume ?? 1.0
        }

        // Interpolate
        guard let prev = prevKeyframe, let next = nextKeyframe else {
            return 1.0
        }

        let totalDuration = CMTimeGetSeconds(CMTimeSubtract(next.time, prev.time))
        let currentOffset = CMTimeGetSeconds(CMTimeSubtract(time, prev.time))
        let progress = Float(currentOffset / totalDuration)

        let curvedProgress = next.curve.value(at: progress)
        return prev.volume + (next.volume - prev.volume) * curvedProgress
    }

    /// Generate AVAudioMix
    func generateAudioMix(for track: AVMutableCompositionTrack) -> AVMutableAudioMix {
        let audioMix = AVMutableAudioMix()
        let parameters = AVMutableAudioMixInputParameters(track: track)

        for i in 0..<keyframes.count - 1 {
            let current = keyframes[i]
            let next = keyframes[i + 1]

            parameters.setVolumeRamp(
                fromStartVolume: current.volume,
                toEndVolume: next.volume,
                timeRange: CMTimeRange(start: current.time, end: next.time)
            )
        }

        audioMix.inputParameters = [parameters]
        return audioMix
    }
}
