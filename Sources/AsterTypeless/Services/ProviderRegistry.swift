import Foundation

// MARK: - Provider definitions

/// All supported LLM providers for chat completion.
enum LLMProvider: String, CaseIterable, Codable, Identifiable {
    case openAI = "openai"
    case qwen = "qwen"
    case groq = "groq"
    case azureOpenAI = "azure_openai"
    case selfHosted = "self_hosted"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .qwen: return "通义千问 (Qwen)"
        case .groq: return "Groq"
        case .azureOpenAI: return "Azure OpenAI"
        case .selfHosted: return "Self-hosted"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .azureOpenAI: return ""
        case .selfHosted: return "http://localhost:8000/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .qwen: return "qwen-plus"
        case .groq: return "llama-3.3-70b-versatile"
        case .azureOpenAI: return ""
        case .selfHosted: return ""
        }
    }

    var supportsOpenAIFormat: Bool { true }

    var setupHint: String {
        switch self {
        case .openAI:
            return "Get your key at platform.openai.com/api-keys"
        case .qwen:
            return "Get your key at bailian.console.aliyun.com"
        case .groq:
            return "Get your key at console.groq.com/keys"
        case .azureOpenAI:
            return "Use your Azure resource endpoint + deployment name"
        case .selfHosted:
            return "vLLM, Ollama, or any OpenAI-compatible server. API key can be 'not-needed'."
        }
    }
}

/// All supported STT providers for speech-to-text.
enum STTProvider: String, CaseIterable, Codable, Identifiable {
    case openAI = "openai"
    case groq = "groq"
    case deepgram = "deepgram"
    case selfHosted = "self_hosted"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI Transcribe"
        case .groq: return "Groq Whisper"
        case .deepgram: return "Deepgram"
        case .selfHosted: return "Self-hosted ASR"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .deepgram: return "https://api.deepgram.com/v1"
        case .selfHosted: return "http://localhost:8001/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-transcribe"
        case .groq: return "whisper-large-v3-turbo"
        case .deepgram: return "nova-2"
        case .selfHosted: return ""
        }
    }

    var usesOpenAITranscriptionFormat: Bool {
        switch self {
        case .openAI, .groq, .selfHosted: return true
        case .deepgram: return false
        }
    }

    var supportsRealtimeStreaming: Bool {
        switch self {
        case .deepgram: return true
        case .openAI, .groq, .selfHosted: return false
        }
    }

    var setupHint: String {
        switch self {
        case .openAI:
            return "Uses the same OpenAI API key"
        case .groq:
            return "Uses the same Groq API key. Batch only (no real-time streaming)."
        case .deepgram:
            return "Get your key at console.deepgram.com. Supports real-time streaming."
        case .selfHosted:
            return "Qwen-ASR, Whisper, or any OpenAI-compatible /audio/transcriptions endpoint."
        }
    }
}

// MARK: - Provider configuration

/// Configuration for a single provider endpoint.
struct ProviderEndpointConfig: Codable, Equatable {
    var baseURL: String
    var apiKey: String
    var model: String

    var isConfigured: Bool {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return false }
        let placeholders = ["sk-your-key", "dg-your-key", "your-key", "changeme"]
        return !placeholders.contains { trimmedKey.localizedCaseInsensitiveContains($0) }
    }
}

/// Full provider configuration for the app.
struct ProviderConfiguration: Codable {
    var selectedLLM: LLMProvider
    var selectedSTT: STTProvider
    var llmConfigs: [String: ProviderEndpointConfig]
    var sttConfigs: [String: ProviderEndpointConfig]
    var language: String

    /// Get the active LLM endpoint config.
    var activeLLMConfig: ProviderEndpointConfig? {
        llmConfigs[selectedLLM.rawValue]
    }

    /// Get the active STT endpoint config.
    var activeSTTConfig: ProviderEndpointConfig? {
        sttConfigs[selectedSTT.rawValue]
    }

    /// Build an OpenAIClient for the active LLM provider.
    func makeLLMClient() -> OpenAIClient? {
        guard let config = activeLLMConfig, config.isConfigured else { return nil }
        return OpenAIClient(baseURL: config.baseURL, apiKey: config.apiKey)
    }

    /// Build an OpenAIClient for the active STT provider (only for OpenAI-compatible ones).
    func makeSTTClient() -> OpenAIClient? {
        guard let config = activeSTTConfig, config.isConfigured else { return nil }
        guard selectedSTT.usesOpenAITranscriptionFormat else { return nil }
        return OpenAIClient(baseURL: config.baseURL, apiKey: config.apiKey)
    }

    static let `default` = ProviderConfiguration(
        selectedLLM: .openAI,
        selectedSTT: .openAI,
        llmConfigs: [:],
        sttConfigs: [:],
        language: "zh-CN"
    )

    /// Migrate from the legacy ProviderRuntimeStatus.
    static func fromLegacy(_ runtime: ProviderRuntimeStatus) -> ProviderConfiguration {
        var config = ProviderConfiguration.default

        // Migrate OpenAI LLM
        if !runtime.openAIAPIKey.isEmpty {
            config.llmConfigs[LLMProvider.openAI.rawValue] = ProviderEndpointConfig(
                baseURL: runtime.openAIBaseURL.isEmpty ? LLMProvider.openAI.defaultBaseURL : runtime.openAIBaseURL,
                apiKey: runtime.openAIAPIKey,
                model: runtime.openAIModel.isEmpty ? LLMProvider.openAI.defaultModel : runtime.openAIModel
            )
        }

        // Migrate OpenAI STT
        if !runtime.openAIAPIKey.isEmpty {
            config.sttConfigs[STTProvider.openAI.rawValue] = ProviderEndpointConfig(
                baseURL: runtime.openAIBaseURL.isEmpty ? STTProvider.openAI.defaultBaseURL : runtime.openAIBaseURL,
                apiKey: runtime.openAIAPIKey,
                model: runtime.openAITranscribeModel.isEmpty ? STTProvider.openAI.defaultModel : runtime.openAITranscribeModel
            )
        }

        // Migrate Deepgram
        if !runtime.deepgramAPIKey.isEmpty {
            config.sttConfigs[STTProvider.deepgram.rawValue] = ProviderEndpointConfig(
                baseURL: runtime.deepgramBaseURL.isEmpty ? STTProvider.deepgram.defaultBaseURL : runtime.deepgramBaseURL,
                apiKey: runtime.deepgramAPIKey,
                model: runtime.deepgramModel.isEmpty ? STTProvider.deepgram.defaultModel : runtime.deepgramModel
            )
            // If Deepgram is configured, prefer it for STT
            config.selectedSTT = .deepgram
        }

        config.language = runtime.deepgramLanguage.isEmpty ? "zh-CN" : runtime.deepgramLanguage

        return config
    }
}

// MARK: - Persistence

@MainActor
final class ProviderConfigStore {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("AsterTypeless", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("providers.json")
    }

    func load() -> ProviderConfiguration? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(ProviderConfiguration.self, from: data)
    }

    func save(_ config: ProviderConfiguration) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
