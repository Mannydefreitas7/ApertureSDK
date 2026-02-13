import Foundation
import AVFoundation
import Accelerate

/// 音频引擎 - 处理音频波形、效果、分析
actor AudioEngine {

    // MARK: - 波形生成
    static let shared: AudioEngine = .init()

    /// 生成音频波形数据
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

        // 下采样到目标数量
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

    /// 生成缩略波形（用于时间线显示）
    static func generateThumbnailWaveform(
        from asset: AVAsset,
        width: Int
    ) async throws -> [Float] {
        return try await generateWaveform(from: asset, samplesPerSecond: width / 5)
    }
}

// MARK: - 音频效果

/// 音频效果处理器
class AudioEffectProcessor {

    /// 音频淡入淡出
    struct FadeEffect {
        var fadeInDuration: CMTime = .zero
        var fadeOutDuration: CMTime = .zero
        var fadeInCurve: FadeCurve = .linear
        var fadeOutCurve: FadeCurve = .linear
    }

    /// 淡变曲线类型
    enum FadeCurve: String, CaseIterable {
        case linear = "线性"
        case exponential = "指数"
        case logarithmic = "对数"
        case sCurve = "S曲线"

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

    /// 应用淡入淡出到音频轨道
    static func applyFade(
        to track: AVMutableCompositionTrack,
        fade: FadeEffect,
        timeRange: CMTimeRange
    ) -> AVMutableAudioMix {
        let audioMix = AVMutableAudioMix()
        let parameters = AVMutableAudioMixInputParameters(track: track)

        var volumeRamps: [(time: CMTime, volume: Float)] = []

        // 淡入
        if fade.fadeInDuration > .zero {
            let fadeInEnd = CMTimeAdd(timeRange.start, fade.fadeInDuration)
            volumeRamps.append((timeRange.start, 0.0))
            volumeRamps.append((fadeInEnd, 1.0))
        }

        // 淡出
        if fade.fadeOutDuration > .zero {
            let fadeOutStart = CMTimeSubtract(timeRange.end, fade.fadeOutDuration)
            volumeRamps.append((fadeOutStart, 1.0))
            volumeRamps.append((timeRange.end, 0.0))
        }

        // 应用音量渐变
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

/// 音频均衡器
struct AudioEqualizer: Equatable {
    /// 预设类型
    enum Preset: String, CaseIterable {
        case flat = "平坦"
        case bass = "低音增强"
        case treble = "高音增强"
        case vocal = "人声增强"
        case acoustic = "原声"
        case electronic = "电子"
        case rock = "摇滚"
        case pop = "流行"
        case jazz = "爵士"
        case classical = "古典"
        case custom = "自定义"
    }

    /// 频段增益 (-12dB to +12dB)
    var bands: [Float] = Array(repeating: 0, count: 10)

    /// 频段频率
    static let frequencies: [String] = [
        "32Hz", "64Hz", "125Hz", "250Hz", "500Hz",
        "1kHz", "2kHz", "4kHz", "8kHz", "16kHz"
    ]

    /// 应用预设
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

/// 音频变声效果
struct VoiceChanger: Equatable {
    /// 变声类型
    enum VoiceType: String, CaseIterable {
        case normal = "正常"
        case male = "男声"
        case female = "女声"
        case child = "童声"
        case robot = "机器人"
        case monster = "怪物"
        case chipmunk = "花栗鼠"
        case deep = "低沉"

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

/// 音频降噪
struct NoiseReduction: Equatable {
    /// 降噪强度 (0-100)
    var strength: Float = 50

    /// 降噪类型
    enum NoiseType: String, CaseIterable {
        case auto = "自动"
        case wind = "风噪"
        case hum = "电流声"
        case hiss = "嘶嘶声"
        case background = "背景噪音"
    }

    var noiseType: NoiseType = .auto
}

// MARK: - 音频分离

/// 音频分离器
class AudioSeparator {

    /// 从视频中分离音频
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

        // 导出为音频文件
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

    /// 将音频合并到视频
    static func mergeAudio(
        videoAsset: AVAsset,
        audioAsset: AVAsset,
        outputURL: URL,
        videoVolume: Float = 1.0,
        audioVolume: Float = 1.0
    ) async throws {
        let composition = AVMutableComposition()

        // 添加视频轨道
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

        // 添加原始音频轨道
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

        // 添加新音频轨道
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

        // 导出
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

/// 音频错误
enum AudioError: LocalizedError {
    case trackCreationFailed
    case noAudioTrack
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .trackCreationFailed: return "创建音轨失败"
        case .noAudioTrack: return "没有找到音轨"
        case .exportFailed: return "导出失败"
        }
    }
}

// MARK: - 音量关键帧

/// 音量关键帧
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

/// 音量关键帧管理器
class VolumeKeyframeManager {
    var keyframes: [VolumeKeyframe] = []

    /// 添加关键帧
    func addKeyframe(at time: CMTime, volume: Float) {
        let keyframe = VolumeKeyframe(time: time, volume: volume)
        keyframes.append(keyframe)
        sortKeyframes()
    }

    /// 删除关键帧
    func removeKeyframe(id: UUID) {
        keyframes.removeAll { $0.id == id }
    }

    /// 排序关键帧
    func sortKeyframes() {
        keyframes.sort { CMTimeCompare($0.time, $1.time) < 0 }
    }

    /// 获取指定时间的音量
    func volume(at time: CMTime) -> Float {
        guard !keyframes.isEmpty else { return 1.0 }

        // 查找前后关键帧
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

        // 如果在所有关键帧之前
        if prevKeyframe == nil {
            return nextKeyframe?.volume ?? 1.0
        }

        // 如果在所有关键帧之后
        if nextKeyframe == nil {
            return prevKeyframe?.volume ?? 1.0
        }

        // 插值
        guard let prev = prevKeyframe, let next = nextKeyframe else {
            return 1.0
        }

        let totalDuration = CMTimeGetSeconds(CMTimeSubtract(next.time, prev.time))
        let currentOffset = CMTimeGetSeconds(CMTimeSubtract(time, prev.time))
        let progress = Float(currentOffset / totalDuration)

        let curvedProgress = next.curve.value(at: progress)
        return prev.volume + (next.volume - prev.volume) * curvedProgress
    }

    /// 生成 AVAudioMix
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
