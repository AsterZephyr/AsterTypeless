import Foundation

enum StreamingTranscriptSource {
    case localPlaceholder
    case providerPlaceholder
    case openAITranscribe

    var title: String {
        switch self {
        case .localPlaceholder:
            return "本地流式占位"
        case .providerPlaceholder:
            return "Provider-ready 占位"
        case .openAITranscribe:
            return "OpenAI Transcribe"
        }
    }
}

struct StreamingTranscriptUpdate {
    var text: String
    var source: StreamingTranscriptSource
    var isFinal: Bool
}

@MainActor
final class StreamingTranscriptEngine {
    private var timer: Timer?
    private var tokens: [String] = []
    private var emittedTokens: [String] = []
    private var quietTicks = 0
    private var isSpeechActive = false
    private var source: StreamingTranscriptSource = .localPlaceholder
    private var onUpdate: ((StreamingTranscriptUpdate) -> Void)?

    // Provider state
    private var providerRuntime: ProviderRuntimeStatus?
    private var transcriptionTask: Task<Void, Never>?

    func start(
        mode: QuickActionMode,
        selection: SelectionContext,
        providerRuntime: ProviderRuntimeStatus,
        onUpdate: @escaping (StreamingTranscriptUpdate) -> Void
    ) {
        stop(finalize: false)

        self.onUpdate = onUpdate
        self.providerRuntime = providerRuntime

        if providerRuntime.canUseOpenAITranscribe {
            // Real provider mode: we'll transcribe when audio is available
            source = .openAITranscribe
            emittedTokens = []
            tokens = []
        } else {
            // Mock mode: simulate streaming transcript
            source = providerRuntime.executionMode == .mockReady ? .localPlaceholder : .providerPlaceholder
            tokens = transcriptTemplate(mode: mode, selection: selection)
            emittedTokens = []
            quietTicks = 0
            isSpeechActive = false

            timer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tick()
                }
            }
        }
    }

    /// Transcribe collected audio data using OpenAI Transcribe API.
    /// Called after recording stops to get the real transcript.
    func transcribeAudio(wavData: Data) {
        guard let runtime = providerRuntime,
              runtime.canUseOpenAITranscribe,
              let client = runtime.makeOpenAIClient()
        else {
            return
        }

        let model = runtime.openAITranscribeModel
        let language = runtime.deepgramLanguage.isEmpty ? nil : String(runtime.deepgramLanguage.prefix(2))

        transcriptionTask = Task { [weak self] in
            guard let self else { return }

            // Emit a "processing" update
            self.onUpdate?(StreamingTranscriptUpdate(
                text: "正在转写...",
                source: .openAITranscribe,
                isFinal: false
            ))

            do {
                let text = try await client.transcribeAudio(
                    model: model,
                    audioData: wavData,
                    language: language
                )

                guard !Task.isCancelled else { return }

                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    self.emittedTokens = [trimmed]
                    self.onUpdate?(StreamingTranscriptUpdate(
                        text: trimmed,
                        source: .openAITranscribe,
                        isFinal: true
                    ))
                } else {
                    self.onUpdate?(StreamingTranscriptUpdate(
                        text: "未检测到语音内容",
                        source: .openAITranscribe,
                        isFinal: true
                    ))
                }
            } catch {
                guard !Task.isCancelled else { return }

                let errorMessage = "转写失败: \(error.localizedDescription)"
                self.onUpdate?(StreamingTranscriptUpdate(
                    text: errorMessage,
                    source: .openAITranscribe,
                    isFinal: true
                ))
            }
        }
    }

    func updateSpeechActivity(isSpeaking: Bool) {
        isSpeechActive = isSpeaking
    }

    @discardableResult
    func stop(finalize: Bool = true) -> String {
        timer?.invalidate()
        timer = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil

        if finalize, !tokens.isEmpty {
            emittedTokens.append(contentsOf: tokens)
            tokens.removeAll()
            publish(isFinal: true)
        }

        let finalText = emittedTokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        onUpdate = nil
        quietTicks = 0
        isSpeechActive = false
        providerRuntime = nil
        return finalText
    }

    // MARK: - Mock streaming

    private func tick() {
        guard !tokens.isEmpty else { return }

        if isSpeechActive {
            quietTicks = 0
            let burstCount = emittedTokens.count < 4 ? 2 : 1
            for _ in 0 ..< burstCount where !tokens.isEmpty {
                emittedTokens.append(tokens.removeFirst())
            }
            publish(isFinal: tokens.isEmpty)
            return
        }

        quietTicks += 1
        if quietTicks >= 8, !emittedTokens.isEmpty {
            publish(isFinal: false)
        }
    }

    private func publish(isFinal: Bool) {
        let text = emittedTokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onUpdate?(
            StreamingTranscriptUpdate(
                text: text,
                source: source,
                isFinal: isFinal
            )
        )
    }

    private func transcriptTemplate(mode: QuickActionMode, selection: SelectionContext) -> [String] {
        let appName = selection.focusedAppName.isEmpty ? "当前输入框" : selection.focusedAppName
        let selected = normalizedSnippet(from: selection.selectedText)

        let seed: String
        switch mode {
        case .dictate:
            seed = selected.isEmpty
                ? "继续整理在 \(appName) 里的这段口述，让它更像可以直接发送的自然文字。"
                : "继续基于已选内容整理这段口述，让它更完整也更自然。"
        case .rewrite:
            seed = selected.isEmpty
                ? "把当前内容改写得更利落一些，减少说明书式的堆叠表达。"
                : "把这段内容继续改写得更利落一些，同时保留原本语气。"
        case .translate:
            seed = selected.isEmpty
                ? "继续把这段内容转换成目标语言，同时保留语气和重点。"
                : "继续翻译选中的内容，保持原意、语气和关键信息。"
        case .ask:
            seed = selection.surroundingText.isEmpty
                ? "先基于当前上下文整理一个可执行的提问方向。"
                : "基于附近上下文继续整理一个更明确的提问方向。"
        }

        return seed
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private func normalizedSnippet(from text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
