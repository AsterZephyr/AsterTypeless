import Foundation

// MARK: - Provider definitions

/// All supported LLM providers for chat completion.
enum LLMProvider: String, CaseIterable, Codable, Identifiable {
    case openAI = "openai"
    case qwen = "qwen"
    case groq = "groq"
    case cerebras = "cerebras"
    case azureOpenAI = "azure_openai"
    case selfHosted = "self_hosted"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .qwen: return "通义千问 (Qwen)"
        case .groq: return "Groq"
        case .cerebras: return "Cerebras"
        case .azureOpenAI: return "Azure OpenAI"
        case .selfHosted: return "Self-hosted"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .cerebras: return "https://api.cerebras.ai/v1"
        case .azureOpenAI: return ""
        case .selfHosted: return "http://localhost:8000/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .qwen: return "qwen-plus"
        case .groq: return "llama-3.3-70b-versatile"
        case .cerebras: return "gpt-oss-120b"
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
        case .cerebras:
            return "Use Cerebras inference endpoint with your API key"
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
    case dashScope = "dashscope"
    case selfHosted = "self_hosted"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI Transcribe"
        case .groq: return "Groq Whisper"
        case .deepgram: return "Deepgram"
        case .dashScope: return "DashScope ASR"
        case .selfHosted: return "Self-hosted ASR"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .deepgram: return "https://api.deepgram.com/v1"
        case .dashScope: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .selfHosted: return "http://localhost:8001/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: return "gpt-4o-transcribe"
        case .groq: return "whisper-large-v3-turbo"
        case .deepgram: return "nova-2"
        case .dashScope: return "qwen-audio-asr"
        case .selfHosted: return ""
        }
    }

    var usesOpenAITranscriptionFormat: Bool {
        switch self {
        case .openAI, .groq, .dashScope, .selfHosted: return true
        case .deepgram: return false
        }
    }

    var supportsRealtimeStreaming: Bool {
        switch self {
        case .deepgram: return true
        case .openAI, .groq, .dashScope, .selfHosted: return false
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
        case .dashScope:
            return "Use DashScope compatible endpoint for Chinese ASR."
        case .selfHosted:
            return "Qwen-ASR, Whisper, or any OpenAI-compatible /audio/transcriptions endpoint."
        }
    }
}

enum ModelPreset: String, CaseIterable, Codable, Identifiable {
    case typelessLike = "typeless_like"
    case chineseFirst = "chinese_first"
    case universal = "universal"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .typelessLike: return "Typeless-like"
        case .chineseFirst: return "中文优先"
        case .universal: return "通用兼容"
        }
    }

    var llmProvider: LLMProvider {
        switch self {
        case .typelessLike: return .cerebras
        case .chineseFirst: return .qwen
        case .universal: return .openAI
        }
    }

    var sttProvider: STTProvider {
        switch self {
        case .typelessLike: return .groq
        case .chineseFirst: return .dashScope
        case .universal: return .openAI
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
    var selectedPreset: ModelPreset
    var selectedLLM: LLMProvider
    var selectedSTT: STTProvider
    var llmConfigs: [String: ProviderEndpointConfig]
    var sttConfigs: [String: ProviderEndpointConfig]
    var language: String
    var contextAwarenessEnabled: Bool
    var lexiconLearningEnabled: Bool
    var preferStableDelivery: Bool

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
        selectedPreset: .universal,
        selectedLLM: .openAI,
        selectedSTT: .openAI,
        llmConfigs: [:],
        sttConfigs: [:],
        language: "zh-CN",
        contextAwarenessEnabled: true,
        lexiconLearningEnabled: true,
        preferStableDelivery: false
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
        config.selectedPreset = .universal

        return config
    }

    mutating func applyPreset(_ preset: ModelPreset) {
        selectedPreset = preset
        selectedLLM = preset.llmProvider
        selectedSTT = preset.sttProvider

        var llmConfig = llmConfigs[selectedLLM.rawValue] ?? ProviderEndpointConfig(
            baseURL: selectedLLM.defaultBaseURL,
            apiKey: "",
            model: selectedLLM.defaultModel
        )
        if llmConfig.baseURL.isEmpty {
            llmConfig.baseURL = selectedLLM.defaultBaseURL
        }
        if llmConfig.model.isEmpty {
            llmConfig.model = selectedLLM.defaultModel
        }
        llmConfigs[selectedLLM.rawValue] = llmConfig

        var sttConfig = sttConfigs[selectedSTT.rawValue] ?? ProviderEndpointConfig(
            baseURL: selectedSTT.defaultBaseURL,
            apiKey: "",
            model: selectedSTT.defaultModel
        )
        if sttConfig.baseURL.isEmpty {
            sttConfig.baseURL = selectedSTT.defaultBaseURL
        }
        if sttConfig.model.isEmpty {
            sttConfig.model = selectedSTT.defaultModel
        }
        sttConfigs[selectedSTT.rawValue] = sttConfig
    }

    var providerSummary: VoiceFlowProviderSummary {
        VoiceFlowProviderSummary(
            preset: selectedPreset,
            llmProvider: selectedLLM.displayName,
            llmModel: activeLLMConfig?.model ?? selectedLLM.defaultModel,
            sttProvider: selectedSTT.displayName,
            sttModel: activeSTTConfig?.model ?? selectedSTT.defaultModel
        )
    }

    enum CodingKeys: String, CodingKey {
        case selectedPreset
        case selectedLLM
        case selectedSTT
        case llmConfigs
        case sttConfigs
        case language
        case contextAwarenessEnabled
        case lexiconLearningEnabled
        case preferStableDelivery
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedPreset = try container.decodeIfPresent(ModelPreset.self, forKey: .selectedPreset) ?? .universal
        selectedLLM = try container.decodeIfPresent(LLMProvider.self, forKey: .selectedLLM) ?? .openAI
        selectedSTT = try container.decodeIfPresent(STTProvider.self, forKey: .selectedSTT) ?? .openAI
        llmConfigs = try container.decodeIfPresent([String: ProviderEndpointConfig].self, forKey: .llmConfigs) ?? [:]
        sttConfigs = try container.decodeIfPresent([String: ProviderEndpointConfig].self, forKey: .sttConfigs) ?? [:]
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? "zh-CN"
        contextAwarenessEnabled = try container.decodeIfPresent(Bool.self, forKey: .contextAwarenessEnabled) ?? true
        lexiconLearningEnabled = try container.decodeIfPresent(Bool.self, forKey: .lexiconLearningEnabled) ?? true
        preferStableDelivery = try container.decodeIfPresent(Bool.self, forKey: .preferStableDelivery) ?? false
    }

    init(
        selectedPreset: ModelPreset,
        selectedLLM: LLMProvider,
        selectedSTT: STTProvider,
        llmConfigs: [String: ProviderEndpointConfig],
        sttConfigs: [String: ProviderEndpointConfig],
        language: String,
        contextAwarenessEnabled: Bool,
        lexiconLearningEnabled: Bool,
        preferStableDelivery: Bool
    ) {
        self.selectedPreset = selectedPreset
        self.selectedLLM = selectedLLM
        self.selectedSTT = selectedSTT
        self.llmConfigs = llmConfigs
        self.sttConfigs = sttConfigs
        self.language = language
        self.contextAwarenessEnabled = contextAwarenessEnabled
        self.lexiconLearningEnabled = lexiconLearningEnabled
        self.preferStableDelivery = preferStableDelivery
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
