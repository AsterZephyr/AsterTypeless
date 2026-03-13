import AVFoundation
import Foundation

@MainActor
final class AudioInputMonitor: ObservableObject {
    @Published private(set) var microphonePermission: PermissionState = .required
    @Published private(set) var level: Double = 0
    @Published private(set) var smoothedLevel: Double = 0
    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var elapsedSeconds: Double = 0

    private let engine = AVAudioEngine()
    private var startDate: Date?
    private var timer: Timer?

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

        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

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

        level = 0
        smoothedLevel = 0
        isSpeaking = false
        elapsedSeconds = 0
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else {
            return
        }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else {
            return
        }

        var sum: Float = 0
        for index in 0 ..< frameCount {
            let sample = channelData[index]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameCount))
        let normalized = min(max(Double(rms) * 18, 0), 1)

        DispatchQueue.main.async {
            self.level = normalized
            self.smoothedLevel = (self.smoothedLevel * 0.72) + (normalized * 0.28)
            self.isSpeaking = self.smoothedLevel > 0.08
        }
    }
}
