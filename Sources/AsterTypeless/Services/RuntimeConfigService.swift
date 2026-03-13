import Foundation

struct RuntimeProviderConfiguration: Codable {
    var preferredProvider: String = "OpenAI + Deepgram"
    var openAIBaseURL: String = "https://api.openai.com/v1"
    var openAIAPIKey: String = ""
    var openAIModel: String = "gpt-5-mini"
    var openAITranscribeModel: String = "gpt-4o-transcribe"
    var deepgramBaseURL: String = "https://api.deepgram.com"
    var deepgramAPIKey: String = ""
    var deepgramModel: String = "nova-2"
    var deepgramLanguage: String = "zh-CN"

    enum CodingKeys: String, CodingKey {
        case preferredProvider = "PreferredProvider"
        case openAIBaseURL = "OpenAIBaseURL"
        case openAIAPIKey = "OpenAIAPIKey"
        case openAIModel = "OpenAIModel"
        case openAITranscribeModel = "OpenAITranscribeModel"
        case deepgramBaseURL = "DeepgramBaseURL"
        case deepgramAPIKey = "DeepgramAPIKey"
        case deepgramModel = "DeepgramModel"
        case deepgramLanguage = "DeepgramLanguage"
    }
}

@MainActor
final class RuntimeConfigService {
    func loadStatus() -> ProviderRuntimeStatus {
        guard let resolved = resolveConfigURL() else {
            return ProviderRuntimeStatus(
                preferredProvider: "Mock",
                sourceDescription: "未发现运行时配置",
                sourcePath: "",
                executionMode: .mockReady,
                openAIConfigured: false,
                deepgramConfigured: false,
                openAIBaseURL: "",
                deepgramBaseURL: "",
                openAIModel: "",
                openAITranscribeModel: "",
                deepgramModel: "",
                deepgramLanguage: ""
            )
        }

        do {
            let data = try Data(contentsOf: resolved.url)
            let configuration = try PropertyListDecoder().decode(RuntimeProviderConfiguration.self, from: data)
            let openAIConfigured = isConfiguredKey(configuration.openAIAPIKey)
            let deepgramConfigured = isConfiguredKey(configuration.deepgramAPIKey)

            let executionMode: ProviderExecutionMode
            if openAIConfigured && deepgramConfigured {
                executionMode = .providerReady
            } else if openAIConfigured || deepgramConfigured {
                executionMode = .partial
            } else {
                executionMode = .mockReady
            }

            return ProviderRuntimeStatus(
                preferredProvider: configuration.preferredProvider,
                sourceDescription: resolved.sourceDescription,
                sourcePath: resolved.url.path,
                executionMode: executionMode,
                openAIConfigured: openAIConfigured,
                deepgramConfigured: deepgramConfigured,
                openAIBaseURL: configuration.openAIBaseURL,
                deepgramBaseURL: configuration.deepgramBaseURL,
                openAIModel: configuration.openAIModel,
                openAITranscribeModel: configuration.openAITranscribeModel,
                deepgramModel: configuration.deepgramModel,
                deepgramLanguage: configuration.deepgramLanguage
            )
        } catch {
            return ProviderRuntimeStatus(
                preferredProvider: "Mock",
                sourceDescription: "配置读取失败",
                sourcePath: resolved.url.path,
                executionMode: .mockReady,
                openAIConfigured: false,
                deepgramConfigured: false,
                openAIBaseURL: "",
                deepgramBaseURL: "",
                openAIModel: "",
                openAITranscribeModel: "",
                deepgramModel: "",
                deepgramLanguage: "",
                lastError: error.localizedDescription
            )
        }
    }

    private func resolveConfigURL() -> (url: URL, sourceDescription: String)? {
        let fileManager = FileManager.default
        let candidateDirectories = configSearchDirectories()

        for directory in candidateDirectories {
            let local = directory.appendingPathComponent("Config/Runtime.local.plist")
            if fileManager.fileExists(atPath: local.path) {
                return (local, "Runtime.local.plist")
            }

            let sample = directory.appendingPathComponent("Config/Runtime.sample.plist")
            if fileManager.fileExists(atPath: sample.path) {
                return (sample, "Runtime.sample.plist")
            }
        }

        return nil
    }

    private func configSearchDirectories() -> [URL] {
        var directories: [URL] = []
        let fileManager = FileManager.default

        if let override = ProcessInfo.processInfo.environment["ASTERTYPELESS_RUNTIME_CONFIG"], !override.isEmpty {
            let overrideURL = URL(fileURLWithPath: override)
            directories.append(overrideURL.deletingLastPathComponent())
        }

        var current = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        directories.append(current)

        for _ in 0..<6 {
            current.deleteLastPathComponent()
            directories.append(current)
        }

        if let bundleParent = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent() as URL? {
            directories.append(bundleParent)
        }

        return deduplicated(directories)
    }

    private func deduplicated(_ directories: [URL]) -> [URL] {
        var seen = Set<String>()
        return directories.filter { url in
            let path = url.standardizedFileURL.path
            return seen.insert(path).inserted
        }
    }

    private func isConfiguredKey(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        let placeholders = ["sk-your-key", "dg-your-key", "your-key", "changeme"]
        return !placeholders.contains { trimmed.localizedCaseInsensitiveContains($0) }
    }
}
