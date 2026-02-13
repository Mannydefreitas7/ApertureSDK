import Foundation
import AVFoundation
import Accelerate
import CoreMedia

// MARK: - 3. Audio Enhancement Module

// MARK: - Audio Visualization

enum VisualizationType: String, CaseIterable {
    case waveform = "Waveform"
    case spectrum = "Spectrum"
    case spectrogram = "Spectrogram"
    case bars = "Bars"
    case circular = "Circular"
    case particles = "Particles"
}

struct AudioVisualization {
    var type: VisualizationType
    var color: CodableColor
    var backgroundColor: CodableColor?
    var sensitivity: Float = 1.0
    var smoothing: Float = 0.8
    var barCount: Int = 64
    var mirrorMode: Bool = false
}

class AudioVisualizer: ObservableObject {
    static let shared = AudioVisualizer()

    @Published var waveformData: [Float] = []
    @Published var spectrumData: [Float] = []
    @Published var isAnalyzing = false

    private let fftSetup: vDSP_DFT_Setup?
    private let fftLength = 2048

    private init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftLength), .FORWARD)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // Generate waveform data
    func generateWaveform(from asset: AVAsset, samplesPerSecond: Int = 100) async throws -> [Float] {
        isAnalyzing = true
        defer { isAnalyzing = false }

        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            throw AudioVisualizerError.noAudioTrack
        }

        let reader = try AVAssetReader(asset: asset)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: settings)
        reader.add(output)
        reader.startReading()

        var samples: [Float] = []
        let samplesPerWindow = 44100 / samplesPerSecond

        var buffer: [Int16] = []

        while reader.status == .reading {
            if let sampleBuffer = output.copyNextSampleBuffer(),
               let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                var length = 0
                var dataPointer: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

                if let data = dataPointer {
                    let int16Pointer = data.withMemoryRebound(to: Int16.self, capacity: length / 2) { $0 }
                    let int16Buffer = UnsafeBufferPointer(start: int16Pointer, count: length / 2)
                    buffer.append(contentsOf: int16Buffer)

                    while buffer.count >= samplesPerWindow {
                        let window = Array(buffer.prefix(samplesPerWindow))
                        buffer.removeFirst(samplesPerWindow)

                        // Calculate RMS
                        var floatWindow = window.map { Float($0) / Float(Int16.max) }
                        var rms: Float = 0
                        vDSP_rmsqv(&floatWindow, 1, &rms, vDSP_Length(floatWindow.count))
                        samples.append(rms)
                    }
                }
                CMSampleBufferInvalidate(sampleBuffer)
            }
        }

        waveformData = samples
        return samples
    }

    // Real-time spectrum analysis
    func analyzeSpectrum(samples: [Float]) -> [Float] {
        guard samples.count >= fftLength, let setup = fftSetup else {
            return []
        }

        var realInput = Array(samples.prefix(fftLength))
        var imagInput = [Float](repeating: 0, count: fftLength)
        var realOutput = [Float](repeating: 0, count: fftLength)
        var imagOutput = [Float](repeating: 0, count: fftLength)

        // Apply Hanning window
        var window = [Float](repeating: 0, count: fftLength)
        vDSP_hann_window(&window, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))
        var windowedInput = [Float](repeating: 0, count: fftLength)
        vDSP_vmul(&realInput, 1, &window, 1, &windowedInput, 1, vDSP_Length(fftLength))
        realInput = windowedInput

        // Execute FFT
        vDSP_DFT_Execute(setup, &realInput, &imagInput, &realOutput, &imagOutput)

        // Calculate magnitude
        var magnitudes = [Float](repeating: 0, count: fftLength / 2)
        var splitComplex = DSPSplitComplex(realp: &realOutput, imagp: &imagOutput)
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftLength / 2))

        // Convert to dB
        var one: Float = 1
        var dbMagnitudes = [Float](repeating: 0, count: fftLength / 2)
        vDSP_vdbcon(&magnitudes, 1, &one, &dbMagnitudes, 1, vDSP_Length(fftLength / 2), 0)

        // Normalize
        var minVal: Float = 0
        var maxVal: Float = 0
        vDSP_minv(&dbMagnitudes, 1, &minVal, vDSP_Length(dbMagnitudes.count))
        vDSP_maxv(&dbMagnitudes, 1, &maxVal, vDSP_Length(dbMagnitudes.count))

        if maxVal > minVal {
            var range = maxVal - minVal
            var normalizedMagnitudes = [Float](repeating: 0, count: fftLength / 2)
            vDSP_vsdiv(&dbMagnitudes, 1, &range, &normalizedMagnitudes, 1, vDSP_Length(dbMagnitudes.count))
            magnitudes = normalizedMagnitudes
        } else {
            magnitudes = dbMagnitudes
        }

        spectrumData = magnitudes
        return magnitudes
    }

    // Generate spectrum animation data
    func generateSpectrumAnimation(from asset: AVAsset, fps: Int = 30) async throws -> [[Float]] {
        let waveform = try await generateWaveform(from: asset, samplesPerSecond: fps * fftLength / 44100)

        var spectrumFrames: [[Float]] = []
        let frameCount = waveform.count / (fftLength / 2)

        for i in 0..<frameCount {
            let startIndex = i * (fftLength / 2)
            let endIndex = min(startIndex + fftLength, waveform.count)

            if endIndex - startIndex >= fftLength {
                let samples = Array(waveform[startIndex..<endIndex])
                let spectrum = analyzeSpectrum(samples: samples)
                spectrumFrames.append(spectrum)
            }
        }

        return spectrumFrames
    }

    enum AudioVisualizerError: Error {
        case noAudioTrack
    }
}

// MARK: - Beat Detection

struct BeatInfo {
    var time: CMTime
    var strength: Float
    var tempo: Double  // BPM
}

class BeatDetector: ObservableObject {
    static let shared = BeatDetector()

    @Published var detectedBeats: [BeatInfo] = []
    @Published var estimatedTempo: Double = 0
    @Published var isDetecting = false

    private init() {}

    // Detect beats
    func detectBeats(from asset: AVAsset, sensitivity: Float = 0.5) async throws -> [BeatInfo] {
        isDetecting = true
        defer { isDetecting = false }

        // Generate waveform
        let waveform = try await AudioVisualizer.shared.generateWaveform(from: asset, samplesPerSecond: 100)

        var beats: [BeatInfo] = []

        // Calculate energy changes
        var energyHistory: [Float] = []
        let windowSize = 10

        for i in 0..<waveform.count {
            let energy = waveform[i] * waveform[i]
            energyHistory.append(energy)

            if energyHistory.count > windowSize {
                energyHistory.removeFirst()
            }

            if energyHistory.count == windowSize {
                let avgEnergy = energyHistory.reduce(0, +) / Float(windowSize)
                let threshold = avgEnergy * (1.5 + sensitivity)

                if energy > threshold && energy > 0.01 {
                    // Beat detected
                    let time = CMTime(seconds: Double(i) / 100.0, preferredTimescale: 600)

                    // Avoid beats that are too close together
                    if beats.isEmpty || CMTimeGetSeconds(CMTimeSubtract(time, beats.last!.time)) > 0.1 {
                        beats.append(BeatInfo(time: time, strength: energy, tempo: 0))
                    }
                }
            }
        }

        // Estimate BPM
        if beats.count > 1 {
            var intervals: [Double] = []
            for i in 1..<beats.count {
                let interval = CMTimeGetSeconds(CMTimeSubtract(beats[i].time, beats[i-1].time))
                intervals.append(interval)
            }

            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            let bpm = 60.0 / avgInterval

            estimatedTempo = bpm

            // Update beat information
            for i in 0..<beats.count {
                beats[i].tempo = bpm
            }
        }

        detectedBeats = beats
        return beats
    }

    // Auto-align to nearest beat
    func snapToNearestBeat(time: CMTime) -> CMTime {
        guard !detectedBeats.isEmpty else { return time }

        var nearestBeat = detectedBeats[0]
        var minDistance = abs(CMTimeGetSeconds(CMTimeSubtract(time, nearestBeat.time)))

        for beat in detectedBeats {
            let distance = abs(CMTimeGetSeconds(CMTimeSubtract(time, beat.time)))
            if distance < minDistance {
                minDistance = distance
                nearestBeat = beat
            }
        }

        return nearestBeat.time
    }

    // Generate cut points based on beats
    func generateCutPoints(beats: [BeatInfo], interval: Int = 4) -> [CMTime] {
        var cutPoints: [CMTime] = []

        for (index, beat) in beats.enumerated() {
            if index % interval == 0 {
                cutPoints.append(beat.time)
            }
        }

        return cutPoints
    }
}

// MARK: - Auto Beat Sync

class AutoBeatSync: ObservableObject {
    static let shared = AutoBeatSync()

    @Published var isSyncing = false
    @Published var syncProgress: Double = 0

    private init() {}

    // Automatically align video clips to music beats
    func syncClipsToBeats(clips: [Clip], musicAsset: AVAsset, beatsPerClip: Int = 4) async throws -> [Clip] {
        isSyncing = true
        defer { isSyncing = false }

        // Detect music beats
        let beats = try await BeatDetector.shared.detectBeats(from: musicAsset)

        guard !beats.isEmpty else { return clips }

        var syncedClips: [Clip] = []
        var currentBeatIndex = 0

        for (index, clip) in clips.enumerated() {
            var newClip = clip

            if currentBeatIndex < beats.count {
                // Set clip start time to beat point
                newClip.startTime = beats[currentBeatIndex].time

                // Calculate clip duration (to next switch point)
                let nextBeatIndex = min(currentBeatIndex + beatsPerClip, beats.count - 1)
                let duration = CMTimeSubtract(beats[nextBeatIndex].time, beats[currentBeatIndex].time)

                // Adjust clip speed to match beat interval
                let originalDuration = newClip.sourceTimeRange.duration
                if CMTimeGetSeconds(originalDuration) > 0 && CMTimeGetSeconds(duration) > 0 {
                    newClip.speed = Float(CMTimeGetSeconds(originalDuration) / CMTimeGetSeconds(duration))
                }

                currentBeatIndex = nextBeatIndex
            }

            syncedClips.append(newClip)
            syncProgress = Double(index + 1) / Double(clips.count)
        }

        return syncedClips
    }
}

// MARK: - Audio Ducking

struct DuckingSettings: Codable {
    var threshold: Float = -20  // dB
    var reduction: Float = -12  // dB
    var attackTime: Float = 0.1  // seconds
    var releaseTime: Float = 0.5  // seconds
    var holdTime: Float = 0.2  // seconds
}

class AudioDucker: ObservableObject {
    static let shared = AudioDucker()

    @Published var isDucking = false
    @Published var settings = DuckingSettings()

    private init() {}

    // Apply ducking (automatically lower background music when voice is present)
    func applyDucking(
        voiceTrack: AVAssetTrack,
        musicTrack: AVAssetTrack,
        settings: DuckingSettings
    ) async throws -> AVAudioMix {
        // Analyze voice track to find active voice segments
        let voiceActivity = try await detectVoiceActivity(track: voiceTrack, threshold: settings.threshold)

        // Create audio mix
        let audioMix = AVMutableAudioMix()

        // Create parameters for music track
        let musicParams = AVMutableAudioMixInputParameters(track: musicTrack)

        // Adjust music volume based on voice activity
        for segment in voiceActivity {
            // Fade in (start reducing volume)
            let duckStartTime = CMTimeSubtract(segment.start, CMTime(seconds: Double(settings.attackTime), preferredTimescale: 600))
            let normalVolume: Float = 1.0
            let duckedVolume = pow(10, settings.reduction / 20)  // dB to linear

            musicParams.setVolumeRamp(fromStartVolume: normalVolume, toEndVolume: duckedVolume,
                                      timeRange: CMTimeRange(start: duckStartTime, duration: CMTime(seconds: Double(settings.attackTime), preferredTimescale: 600)))

            // Fade out (restore volume)
            let duckEndTime = CMTimeAdd(segment.end, CMTime(seconds: Double(settings.holdTime), preferredTimescale: 600))
            musicParams.setVolumeRamp(fromStartVolume: duckedVolume, toEndVolume: normalVolume,
                                      timeRange: CMTimeRange(start: duckEndTime, duration: CMTime(seconds: Double(settings.releaseTime), preferredTimescale: 600)))
        }

        audioMix.inputParameters = [musicParams]
        return audioMix
    }

    private func detectVoiceActivity(track: AVAssetTrack, threshold: Float) async throws -> [CMTimeRange] {
        // Simplified implementation: detect audio energy above threshold
        var segments: [CMTimeRange] = []

        // Actual implementation would read audio samples and analyze energy
        // Return empty array as placeholder

        return segments
    }
}

// MARK: - Reverb Effects

enum ReverbPreset: String, CaseIterable {
    case none = "None"
    case smallRoom = "Small Room"
    case mediumRoom = "Medium Room"
    case largeRoom = "Large Room"
    case hall = "Hall"
    case cathedral = "Cathedral"
    case plate = "Plate Reverb"
    case spring = "Spring Reverb"

    var parameters: ReverbParameters {
        switch self {
        case .none:
            return ReverbParameters(wetDryMix: 0, decay: 0, preDelay: 0)
        case .smallRoom:
            return ReverbParameters(wetDryMix: 20, decay: 0.3, preDelay: 5)
        case .mediumRoom:
            return ReverbParameters(wetDryMix: 30, decay: 0.6, preDelay: 10)
        case .largeRoom:
            return ReverbParameters(wetDryMix: 40, decay: 1.0, preDelay: 20)
        case .hall:
            return ReverbParameters(wetDryMix: 50, decay: 2.0, preDelay: 30)
        case .cathedral:
            return ReverbParameters(wetDryMix: 60, decay: 4.0, preDelay: 50)
        case .plate:
            return ReverbParameters(wetDryMix: 40, decay: 1.5, preDelay: 0)
        case .spring:
            return ReverbParameters(wetDryMix: 35, decay: 0.8, preDelay: 5)
        }
    }
}

struct ReverbParameters: Codable {
    var wetDryMix: Float  // 0-100
    var decay: Float  // 秒
    var preDelay: Float  // 毫秒
    var highCut: Float = 8000  // Hz
    var lowCut: Float = 100  // Hz
}

// MARK: - Spatial Audio

enum SpatialAudioFormat: String, CaseIterable {
    case stereo = "Stereo"
    case surround51 = "5.1 Surround"
    case surround71 = "7.1 Surround"
    case dolbyAtmos = "Dolby Atmos"
    case binaural = "Binaural 3D"
}

struct SpatialAudioPosition: Codable {
    var azimuth: Float  // -180 to 180 degrees (horizontal angle)
    var elevation: Float  // -90 to 90 degrees (vertical angle)
    var distance: Float  // 0 to 1 (relative distance)

    static let center = SpatialAudioPosition(azimuth: 0, elevation: 0, distance: 0.5)
    static let left = SpatialAudioPosition(azimuth: -90, elevation: 0, distance: 0.5)
    static let right = SpatialAudioPosition(azimuth: 90, elevation: 0, distance: 0.5)
    static let behind = SpatialAudioPosition(azimuth: 180, elevation: 0, distance: 0.5)
}

class SpatialAudioProcessor: ObservableObject {
    static let shared = SpatialAudioProcessor()

    @Published var format: SpatialAudioFormat = .stereo
    @Published var listenerPosition = SpatialAudioPosition.center

    private init() {}

    // 将单声道/立体声转换为空间音频
    func applySpatialPosition(
        to asset: AVAsset,
        position: SpatialAudioPosition
    ) async throws -> AVAsset {
        // 使用 HRTF（头相关传输函数）处理
        // 简化实现
        return asset
    }

    // Create surround sound mix
    func createSurroundMix(
        tracks: [(track: AVAssetTrack, position: SpatialAudioPosition)]
    ) async throws -> AVAudioMix {
        let audioMix = AVMutableAudioMix()

        var inputParameters: [AVMutableAudioMixInputParameters] = []

        for (track, position) in tracks {
            let params = AVMutableAudioMixInputParameters(track: track)

            // Set channel volume based on position
            // Simplified implementation: only handle left-right balance
            let pan = position.azimuth / 90.0  // -1 to 1
            let leftVolume = Float(max(0, 1 - pan))
            let rightVolume = Float(max(0, 1 + pan))

            // Set volume (this is simplified stereo panning)
            params.setVolume(leftVolume, at: .zero)

            inputParameters.append(params)
        }

        audioMix.inputParameters = inputParameters
        return audioMix
    }
}

// MARK: - Audio Recording

import AVFAudio

class AudioRecorder: ObservableObject {
    static let shared = AudioRecorder()

    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?

    private init() {}

    // Start recording
    func startRecording() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
        #endif

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        isRecording = true
        recordingURL = url
        recordingTime = 0

        // Update timer and level
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            self.recordingTime = recorder.currentTime
            recorder.updateMeters()
            self.audioLevel = recorder.averagePower(forChannel: 0)
        }

        return url
    }

    // Stop recording
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif

        return recordingURL
    }

    // Pause recording
    func pauseRecording() {
        audioRecorder?.pause()
    }

    // Resume recording
    func resumeRecording() {
        audioRecorder?.record()
    }
}

// MARK: - Podcast Processing

struct PodcastSettings: Codable {
    var removeFillerWords: Bool = true
    var normalizeVolume: Bool = true
    var reduceBackgroundNoise: Bool = true
    var enhanceVoice: Bool = true
    var autoLevelMultipleSpeakers: Bool = true
}

class PodcastProcessor: ObservableObject {
    static let shared = PodcastProcessor()

    @Published var isProcessing = false
    @Published var processProgress: Double = 0

    private init() {}

    // Process podcast audio
    func processPodcast(asset: AVAsset, settings: PodcastSettings) async throws -> URL {
        isProcessing = true
        defer { isProcessing = false }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("podcast_processed.m4a")

        // Apply various processing
        // Simplified implementation

        return outputURL
    }

    // Detect and remove filler words (um, ah, uh, etc.)
    func detectFillerWords(in asset: AVAsset) async throws -> [CMTimeRange] {
        // Use speech recognition to detect filler words
        var fillerRanges: [CMTimeRange] = []

        // Actual implementation would use Speech framework

        return fillerRanges
    }

    // Detect speaker changes
    func detectSpeakerChanges(in asset: AVAsset) async throws -> [CMTime] {
        // Use speaker diarization
        var switchPoints: [CMTime] = []

        // Actual implementation would use ML models

        return switchPoints
    }
}

// MARK: - Music Library Integration

struct MusicTrack: Identifiable, Codable {
    let id: UUID
    var title: String
    var artist: String
    var duration: TimeInterval
    var bpm: Double?
    var genre: String?
    var mood: String?
    var url: URL?
    var isRoyaltyFree: Bool

    init(id: UUID = UUID(), title: String, artist: String, duration: TimeInterval, bpm: Double? = nil, genre: String? = nil, mood: String? = nil, url: URL? = nil, isRoyaltyFree: Bool = true) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.bpm = bpm
        self.genre = genre
        self.mood = mood
        self.url = url
        self.isRoyaltyFree = isRoyaltyFree
    }
}

class MusicLibrary: ObservableObject {
    static let shared = MusicLibrary()

    @Published var tracks: [MusicTrack] = []
    @Published var categories: [String] = ["All", "Happy", "Sad", "Inspiring", "Relaxed", "Romantic", "Epic", "Electronic", "Classical"]
    @Published var isLoading = false

    private init() {
        loadBuiltInTracks()
    }

    private func loadBuiltInTracks() {
        // Built-in sample tracks
        tracks = [
            MusicTrack(title: "Upbeat Corporate", artist: "Stock Music", duration: 120, bpm: 120, genre: "Corporate", mood: "Happy"),
            MusicTrack(title: "Inspiring Piano", artist: "Stock Music", duration: 180, bpm: 80, genre: "Classical", mood: "Inspiring"),
            MusicTrack(title: "Chill Lofi", artist: "Stock Music", duration: 240, bpm: 85, genre: "Lofi", mood: "Relaxed"),
            MusicTrack(title: "Epic Cinematic", artist: "Stock Music", duration: 150, bpm: 100, genre: "Cinematic", mood: "Epic"),
            MusicTrack(title: "Happy Ukulele", artist: "Stock Music", duration: 90, bpm: 130, genre: "Acoustic", mood: "Happy"),
        ]
    }

    // Search tracks
    func search(query: String) -> [MusicTrack] {
        guard !query.isEmpty else { return tracks }

        return tracks.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.artist.localizedCaseInsensitiveContains(query) ||
            ($0.genre?.localizedCaseInsensitiveContains(query) ?? false) ||
            ($0.mood?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    // Filter by mood
    func filterByMood(_ mood: String) -> [MusicTrack] {
        guard mood != "All" else { return tracks }
        return tracks.filter { $0.mood == mood }
    }

    // Filter by BPM
    func filterByBPM(min: Double, max: Double) -> [MusicTrack] {
        return tracks.filter {
            guard let bpm = $0.bpm else { return false }
            return bpm >= min && bpm <= max
        }
    }

    // Recommend music (based on video content)
    func recommendMusic(forVideoDuration duration: TimeInterval, mood: String?) async -> [MusicTrack] {
        var recommended = tracks

        // Filter by duration
        recommended = recommended.filter {
            $0.duration >= duration * 0.8 && $0.duration <= duration * 1.5
        }

        // Filter by mood
        if let mood = mood {
            recommended = recommended.filter { $0.mood == mood }
        }

        return recommended
    }
}
