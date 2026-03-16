import Foundation

/// Deepgram real-time WebSocket streaming transcription client.
/// Sends raw PCM audio and receives interim/final transcripts.
final class DeepgramStreamingClient: NSObject, @unchecked Sendable {

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var onTranscript: ((String, Bool) -> Void)?  // (text, isFinal)
    private var onError: ((String) -> Void)?
    private var keepAliveTimer: Timer?
    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let language: String
    private let sampleRate: Int

    init(
        apiKey: String,
        baseURL: String = "wss://api.deepgram.com/v1",
        model: String = "nova-2",
        language: String = "zh-CN",
        sampleRate: Int = 48000
    ) {
        self.apiKey = apiKey
        // Convert http(s) to ws(s) if needed
        var wsURL = baseURL
        if wsURL.hasPrefix("https://") {
            wsURL = "wss://" + wsURL.dropFirst(8)
        } else if wsURL.hasPrefix("http://") {
            wsURL = "ws://" + wsURL.dropFirst(7)
        }
        // Remove trailing /v1 if present (we'll add it back with params)
        if wsURL.hasSuffix("/v1") {
            wsURL = String(wsURL.dropLast(3))
        }
        self.baseURL = wsURL
        self.model = model
        self.language = language
        self.sampleRate = sampleRate
        super.init()
    }

    func connect(
        onTranscript: @escaping (String, Bool) -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.onTranscript = onTranscript
        self.onError = onError

        var params = [
            "model=\(model)",
            "language=\(language)",
            "encoding=linear16",
            "sample_rate=\(sampleRate)",
            "channels=1",
            "interim_results=true",
            "punctuate=true",
            "smart_format=true",
            "endpointing=300",
        ]

        let urlString = "\(baseURL)/v1/listen?\(params.joined(separator: "&"))"
        guard let url = URL(string: urlString) else {
            onError("Invalid Deepgram URL: \(urlString)")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()

        receiveMessages()
        startKeepAlive()
    }

    /// Send raw 16-bit PCM audio data.
    func sendAudio(_ pcmData: Data) {
        guard let task = webSocketTask else { return }
        task.send(.data(pcmData)) { error in
            if let error {
                self.onError?("Send error: \(error.localizedDescription)")
            }
        }
    }

    /// Signal end of audio stream.
    func finishAudio() {
        guard let task = webSocketTask else { return }
        let finalize = "{\"type\": \"Finalize\"}"
        task.send(.string(finalize)) { _ in }
    }

    /// Close the WebSocket connection.
    func disconnect() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil

        let closeStream = "{\"type\": \"CloseStream\"}"
        webSocketTask?.send(.string(closeStream)) { _ in }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.webSocketTask?.cancel(with: .normalClosure, reason: nil)
            self?.webSocketTask = nil
            self?.session?.invalidateAndCancel()
            self?.session = nil
        }
    }

    // MARK: - Private

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self.receiveMessages()

            case .failure(let error):
                self.onError?("WebSocket receive error: \(error.localizedDescription)")
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        let messageType = json["type"] as? String ?? ""

        if messageType == "Results" {
            guard let channel = json["channel"] as? [String: Any],
                  let alternatives = channel["alternatives"] as? [[String: Any]],
                  let firstAlt = alternatives.first,
                  let transcript = firstAlt["transcript"] as? String,
                  !transcript.isEmpty
            else { return }

            let isFinal = json["is_final"] as? Bool ?? false
            let speechFinal = json["speech_final"] as? Bool ?? false

            DispatchQueue.main.async {
                self.onTranscript?(transcript, isFinal || speechFinal)
            }
        } else if messageType == "Error" || messageType == "error" {
            let errorMsg = json["message"] as? String ?? json["description"] as? String ?? "Unknown error"
            DispatchQueue.main.async {
                self.onError?(errorMsg)
            }
        }
    }

    private func startKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            guard let self, let task = self.webSocketTask else { return }
            let keepAlive = "{\"type\": \"KeepAlive\"}"
            task.send(.string(keepAlive)) { _ in }
        }
    }
}
