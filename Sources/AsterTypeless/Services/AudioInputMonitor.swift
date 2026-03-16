import AVFoundation
import Foundation

/// Thread-safe storage for PCM audio buffers collected during recording.
private actor PCMBufferStore {
    private var buffers: [Data] = []

    func append(_ data: Data) {
        buffers.append(data)
    }

    func collectAll() -> [Data] {
        buffers
    }

    func clear() {
        buffers.removeAll()
    }
}

/// Receives level updates from the audio thread and posts to main thread.
fileprivate final class AudioLevelRelay: @unchecked Sendable {
    weak var target: AudioInputMonitor?

    func update(_ normalized: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let monitor = self?.target else { return }
            monitor.level = normalized
            monitor.smoothedLevel = (monitor.smoothedLevel * 0.72) + (normalized * 0.28)
            monitor.isSpeaking = monitor.smoothedLevel > 0.08
        }
    }
}

/// Processes audio buffers on the audio thread, outside MainActor.
/// This avoids Swift 6 strict concurrency violations from installTap callbacks.
private final class AudioTapProcessor: @unchecked Sendable {
    private let bufferStore: PCMBufferStore
    private let levelRelay: AudioLevelRelay
    var onPCMChunk: ((Data) -> Void)?  // Optional: for real-time streaming to Deepgram

    init(bufferStore: PCMBufferStore, levelRelay: AudioLevelRelay) {
        self.bufferStore = bufferStore
        self.levelRelay = levelRelay
    }

    func process(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        // Convert float samples to 16-bit PCM
        var pcmData = Data(capacity: frameCount * 2)
        for index in 0 ..< frameCount {
            let sample = channelData[index]
            let clamped = max(-1.0, min(1.0, sample))
            var int16Sample = Int16(clamped * 32767)
            pcmData.append(Data(bytes: &int16Sample, count: 2))
        }

        Task {
            await bufferStore.append(pcmData)
        }

        // Forward PCM chunk for real-time streaming (e.g. Deepgram)
        onPCMChunk?(pcmData)

        // Compute RMS
        var sum: Float = 0
        for index in 0 ..< frameCount {
            let sample = channelData[index]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameCount))
        let normalized = min(max(Double(rms) * 18, 0), 1)
        levelRelay.update(normalized)
    }
}

@MainActor
final class AudioInputMonitor: ObservableObject {
    @Published private(set) var microphonePermission: PermissionState = .required
    @Published var level: Double = 0
    @Published var smoothedLevel: Double = 0
    @Published var isSpeaking: Bool = false
    @Published private(set) var elapsedSeconds: Double = 0

    private let engine = AVAudioEngine()
    private var startDate: Date?
    private var timer: Timer?
    private let bufferStore = PCMBufferStore()
    private var tapProcessor: AudioTapProcessor?

    func refreshPermissionState() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphonePermission = .granted
        case .notDetermined:
            microphonePermission = .required
        case .denied, .restricted:
            microphonePermission = .unavailable
        @unknown default:
            microphonePermission = .required
        }
    }

    func requestPermission() async -> Bool {
        refreshPermissionState()

        if microphonePermission == .granted {
            return true
        }

        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { accepted in
                continuation.resume(returning: accepted)
            }
        }

        refreshPermissionState()
        return granted
    }

    func startMonitoring() async -> Bool {
        let granted = await requestPermission()
        guard granted else {
            return false
        }

        stopMonitoring()
        await bufferStore.clear()

        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        // Create relay and processor completely outside MainActor closures
        let relay = AudioLevelRelay()
        relay.target = self
        let processor = AudioTapProcessor(bufferStore: bufferStore, levelRelay: relay)
        tapProcessor = processor

        // IMPORTANT: @Sendable closure to prevent inheriting MainActor isolation
        let tapHandler: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, time in
            processor.process(buffer: buffer, time: time)
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format, block: tapHandler)

        do {
            engine.prepare()
            try engine.start()
            startDate = .now
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let startDate = self.startDate else { return }
                    self.elapsedSeconds = Date().timeIntervalSince(startDate)
                }
            }
            return true
        } catch {
            microphonePermission = .unavailable
            return false
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        startDate = nil

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        tapProcessor = nil

        level = 0
        smoothedLevel = 0
        isSpeaking = false
        elapsedSeconds = 0
    }

    /// Collect all captured PCM data as a WAV file suitable for transcription API.
    func collectWAVData() async -> Data? {
        let captured = await bufferStore.collectAll()
        guard !captured.isEmpty else { return nil }

        let rawPCM = captured.reduce(Data()) { $0 + $1 }
        guard !rawPCM.isEmpty else { return nil }

        let inputFormat = engine.inputNode.inputFormat(forBus: 0)
        return createWAVFile(
            pcmData: rawPCM,
            sampleRate: UInt32(inputFormat.sampleRate),
            channels: UInt16(inputFormat.channelCount),
            bitsPerSample: 16
        )
    }

    /// Set a callback to receive raw PCM chunks in real-time (for Deepgram streaming).
    func setStreamingCallback(_ callback: ((Data) -> Void)?) {
        tapProcessor?.onPCMChunk = callback
    }

    /// Clear collected PCM buffers.
    func clearBuffers() async {
        await bufferStore.clear()
    }

    private func createWAVFile(pcmData: Data, sampleRate: UInt32, channels: UInt16, bitsPerSample: UInt16) -> Data {
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(pcmData.count)
        let fileSize = 36 + dataSize

        var header = Data()

        header.append("RIFF".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        header.append("WAVE".data(using: .ascii)!)

        header.append("fmt ".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        header.append("data".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        return header + pcmData
    }
}
