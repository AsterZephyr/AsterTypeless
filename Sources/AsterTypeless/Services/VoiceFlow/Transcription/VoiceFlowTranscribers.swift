import Foundation

@MainActor
protocol RealtimeTranscriber: AnyObject {
    var audioConsumer: ((Data) -> Void)? { get }
    func start(onUpdate: @escaping @Sendable (String, Bool) -> Void, onError: @escaping @Sendable (String) -> Void)
    func stop() async -> String
    func cancel()
}

@MainActor
protocol BatchTranscriber {
    func transcribe(
        wavData: Data,
        providerRuntime: ProviderRuntimeStatus,
        providerConfig: ProviderConfiguration,
        context: VoiceFlowContext,
        lexiconHint: String?
    ) async throws -> String
}

@MainActor
final class DeepgramRealtimeTranscriber: RealtimeTranscriber {
    private let client: DeepgramStreamingClient
    private var latestText = ""
    private var latestFinalText = ""
    private var hasStarted = false

    init(apiKey: String, baseURL: String, model: String, language: String) {
        client = DeepgramStreamingClient(
            apiKey: apiKey,
            baseURL: baseURL,
            model: model,
            language: language
        )
    }

    var audioConsumer: ((Data) -> Void)? {
        { [weak self] chunk in
            self?.client.sendAudio(chunk)
        }
    }

    func start(onUpdate: @escaping @Sendable (String, Bool) -> Void, onError: @escaping @Sendable (String) -> Void) {
        guard !hasStarted else { return }
        hasStarted = true
        client.connect { [weak self] text, isFinal in
            self?.latestText = text
            if isFinal {
                self?.latestFinalText = text
            }
            onUpdate(text, isFinal)
        } onError: { message in
            onError(message)
        }
    }

    func stop() async -> String {
        guard hasStarted else { return latestFinalText.isEmpty ? latestText : latestFinalText }
        client.finishAudio()
        try? await Task.sleep(nanoseconds: 450_000_000)
        client.disconnect()
        hasStarted = false
        return latestFinalText.isEmpty ? latestText : latestFinalText
    }

    func cancel() {
        client.disconnect()
        hasStarted = false
    }
}

struct OpenAICompatibleBatchTranscriber: BatchTranscriber {
    func transcribe(
        wavData: Data,
        providerRuntime: ProviderRuntimeStatus,
        providerConfig: ProviderConfiguration,
        context: VoiceFlowContext,
        lexiconHint: String?
    ) async throws -> String {
        guard let client = providerConfig.makeSTTClient() ?? providerRuntime.makeSTTClient() else {
            return ""
        }

        let model = providerConfig.activeSTTConfig?.model.isEmpty == false
            ? providerConfig.activeSTTConfig?.model ?? providerRuntime.effectiveSTTModel
            : providerRuntime.effectiveSTTModel

        return try await client.transcribeAudio(
            model: model,
            audioData: wavData,
            language: context.locale.isEmpty ? nil : String(context.locale.prefix(2)),
            prompt: lexiconHint
        )
    }
}

@MainActor
final class VoiceFlowTranscriptionCoordinator {
    private var realtimeTranscriber: RealtimeTranscriber?
    private let batchTranscriber: BatchTranscriber

    init(batchTranscriber: BatchTranscriber = OpenAICompatibleBatchTranscriber()) {
        self.batchTranscriber = batchTranscriber
    }

    var audioConsumer: ((Data) -> Void)? {
        realtimeTranscriber?.audioConsumer
    }

    func startRealtimeIfAvailable(
        providerConfig: ProviderConfiguration,
        onUpdate: @escaping @Sendable (String, Bool) -> Void,
        onError: @escaping @Sendable (String) -> Void
    ) {
        guard providerConfig.selectedSTT == .deepgram,
              let config = providerConfig.activeSTTConfig,
              config.isConfigured
        else {
            realtimeTranscriber = nil
            return
        }

        let transcriber = DeepgramRealtimeTranscriber(
            apiKey: config.apiKey,
            baseURL: config.baseURL,
            model: config.model,
            language: providerConfig.language
        )
        realtimeTranscriber = transcriber
        transcriber.start(onUpdate: onUpdate, onError: onError)
    }

    func stopRealtime() async -> String {
        let final = await realtimeTranscriber?.stop() ?? ""
        realtimeTranscriber = nil
        return final
    }

    func cancelRealtime() {
        realtimeTranscriber?.cancel()
        realtimeTranscriber = nil
    }

    func transcribeBatch(
        wavData: Data,
        providerRuntime: ProviderRuntimeStatus,
        providerConfig: ProviderConfiguration,
        context: VoiceFlowContext,
        lexiconHint: String?
    ) async throws -> String {
        try await batchTranscriber.transcribe(
            wavData: wavData,
            providerRuntime: providerRuntime,
            providerConfig: providerConfig,
            context: context,
            lexiconHint: lexiconHint
        )
    }
}
