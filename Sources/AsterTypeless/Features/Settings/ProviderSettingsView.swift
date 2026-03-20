import SwiftUI

struct ProviderSettingsView: View {
    @ObservedObject var model: TypelessAppModel
    @State private var testResult: String = ""
    @State private var isTesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Provider 预设")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text(model.providerConfig.selectedPreset.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }

                Text("先选一组模型组合，再按需手工覆盖 endpoint、key 和 model。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                Picker("Preset", selection: $model.providerConfig.selectedPreset) {
                    ForEach(ModelPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.providerConfig.selectedPreset) { _, preset in
                    model.providerConfig.applyPreset(preset)
                    model.saveProviderConfig()
                }
            }
            .cardSurface()

            // LLM Provider
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("LLM Provider")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    statusDot(configured: model.providerConfig.activeLLMConfig?.isConfigured == true)
                }

                Text("文本生成、改写、翻译。支持任何 OpenAI 兼容接口。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                Picker("LLM", selection: $model.providerConfig.selectedLLM) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.providerConfig.selectedLLM) { _, _ in
                    ensureLLMConfigExists()
                    model.saveProviderConfig()
                }

                endpointFields(
                    config: llmBinding,
                    placeholder: model.providerConfig.selectedLLM.defaultBaseURL,
                    modelPlaceholder: model.providerConfig.selectedLLM.defaultModel,
                    hint: model.providerConfig.selectedLLM.setupHint
                )
            }
            .cardSurface()

            // STT Provider
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("STT Provider")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    statusDot(configured: model.providerConfig.activeSTTConfig?.isConfigured == true)
                }

                Text("语音转文字。支持 OpenAI Whisper 兼容接口或 Deepgram。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                Picker("STT", selection: $model.providerConfig.selectedSTT) {
                    ForEach(STTProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.providerConfig.selectedSTT) { _, _ in
                    ensureSTTConfigExists()
                    model.saveProviderConfig()
                }

                endpointFields(
                    config: sttBinding,
                    placeholder: model.providerConfig.selectedSTT.defaultBaseURL,
                    modelPlaceholder: model.providerConfig.selectedSTT.defaultModel,
                    hint: model.providerConfig.selectedSTT.setupHint
                )
            }
            .cardSurface()

            // Language
            VStack(alignment: .leading, spacing: 8) {
                Text("输出语言")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                HStack(spacing: 8) {
                    ForEach(["zh-CN", "en", "ja", "ko"], id: \.self) { lang in
                        Button {
                            model.providerConfig.language = lang
                            model.saveProviderConfig()
                        } label: {
                            Text(languageLabel(lang))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    model.providerConfig.language == lang
                                        ? AppTheme.accent.opacity(0.15)
                                        : Color.clear,
                                    in: Capsule()
                                )
                                .foregroundStyle(
                                    model.providerConfig.language == lang
                                        ? AppTheme.accent
                                        : AppTheme.muted
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .cardSurface()

            // Actions
            HStack(spacing: 12) {
                Button {
                    model.saveProviderConfig()
                    testResult = "Saved"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if testResult == "Saved" { testResult = "" }
                    }
                } label: {
                    Label("保存并生效", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.accent)

                Button {
                    runConnectionTest()
                } label: {
                    Label(isTesting ? "测试中..." : "测试连接", systemImage: "network")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isTesting)
            }

            if !testResult.isEmpty {
                Text(testResult)
                    .font(.caption)
                    .foregroundStyle(testResult.contains("OK") || testResult == "Saved" ? AppTheme.success : AppTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .insetSurface()
            }

            // Status
            statusSummary
        }
    }

    // MARK: - Endpoint fields

    private func endpointFields(
        config: Binding<ProviderEndpointConfig>,
        placeholder: String,
        modelPlaceholder: String,
        hint: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Base URL (e.g. http://IP:port/v1)", text: config.baseURL, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

            HStack(spacing: 8) {
                SecureField("API Key", text: config.apiKey, prompt: Text("not-needed for self-hosted"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                TextField("Model", text: config.model, prompt: Text(modelPlaceholder))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            Text(hint)
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)
        }
        .insetSurface()
    }

    // MARK: - Status

    private func statusDot(configured: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(configured ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(configured ? "Ready" : "Not configured")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(configured ? AppTheme.success : AppTheme.warning)
        }
    }

    private var statusSummary: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LLM")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                Text(model.providerRuntime.canUseOpenAI
                     ? "\(model.providerRuntime.openAIModel.components(separatedBy: "/").last ?? "ready")"
                     : "Not connected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.providerRuntime.canUseOpenAI ? AppTheme.success : AppTheme.warning)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("STT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                Text(model.providerRuntime.canUseOpenAITranscribe
                     ? "\(model.providerRuntime.effectiveSTTModel.components(separatedBy: "/").last ?? "ready")"
                     : "Not connected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.providerRuntime.canUseOpenAITranscribe ? AppTheme.success : AppTheme.warning)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Mode")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                Text(model.providerRuntime.executionMode.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }

            Spacer()
        }
        .insetSurface()
    }

    // MARK: - Connection test

    private func runConnectionTest() {
        isTesting = true
        testResult = ""

        Task {
            var results: [String] = []

            // Test LLM
            if let llmConfig = model.providerConfig.activeLLMConfig, llmConfig.isConfigured {
                let client = OpenAIClient(baseURL: llmConfig.baseURL, apiKey: llmConfig.apiKey)
                do {
                    let reply = try await client.chatCompletion(
                        model: llmConfig.model,
                        messages: [ChatMessage(role: "user", content: "say OK")],
                        temperature: 0,
                        maxTokens: 10
                    )
                    results.append("LLM: OK (\(reply.prefix(20)))")
                } catch {
                    results.append("LLM: FAIL (\(error.localizedDescription.prefix(60)))")
                }
            } else {
                results.append("LLM: not configured")
            }

            // Test STT
            if let sttConfig = model.providerConfig.activeSTTConfig, sttConfig.isConfigured {
                if model.providerConfig.selectedSTT.usesOpenAITranscriptionFormat {
                    let client = OpenAIClient(baseURL: sttConfig.baseURL, apiKey: sttConfig.apiKey)
                    do {
                        // Send a tiny silent WAV to test the endpoint
                        let silentWAV = generateSilentWAV()
                        let text = try await client.transcribeAudio(model: sttConfig.model, audioData: silentWAV)
                        results.append("STT: OK (response: '\(text.prefix(20))')")
                    } catch {
                        results.append("STT: FAIL (\(error.localizedDescription.prefix(60)))")
                    }
                } else {
                    results.append("STT: configured (Deepgram, WebSocket test not supported here)")
                }
            } else {
                results.append("STT: not configured")
            }

            testResult = results.joined(separator: "\n")
            isTesting = false
        }
    }

    private func generateSilentWAV() -> Data {
        let sampleRate: UInt32 = 16000
        let numSamples: UInt32 = 16000 // 1 second
        let dataSize = numSamples * 2
        let fileSize: UInt32 = 36 + dataSize

        var header = Data()
        header.append("RIFF".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        header.append("WAVE".data(using: .ascii)!)
        header.append("fmt ".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: (sampleRate * 2).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(2).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) })
        header.append("data".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        header.append(Data(count: Int(dataSize)))

        return header
    }

    // MARK: - Bindings

    private var llmBinding: Binding<ProviderEndpointConfig> {
        let provider = model.providerConfig.selectedLLM
        return Binding(
            get: {
                model.providerConfig.llmConfigs[provider.rawValue] ?? ProviderEndpointConfig(
                    baseURL: provider.defaultBaseURL, apiKey: "", model: provider.defaultModel
                )
            },
            set: { model.providerConfig.llmConfigs[provider.rawValue] = $0 }
        )
    }

    private var sttBinding: Binding<ProviderEndpointConfig> {
        let provider = model.providerConfig.selectedSTT
        return Binding(
            get: {
                model.providerConfig.sttConfigs[provider.rawValue] ?? ProviderEndpointConfig(
                    baseURL: provider.defaultBaseURL, apiKey: "", model: provider.defaultModel
                )
            },
            set: { model.providerConfig.sttConfigs[provider.rawValue] = $0 }
        )
    }

    private func ensureLLMConfigExists() {
        let provider = model.providerConfig.selectedLLM
        if model.providerConfig.llmConfigs[provider.rawValue] == nil {
            model.providerConfig.llmConfigs[provider.rawValue] = ProviderEndpointConfig(
                baseURL: provider.defaultBaseURL,
                apiKey: "",
                model: provider.defaultModel
            )
        }
    }

    private func ensureSTTConfigExists() {
        let provider = model.providerConfig.selectedSTT
        if model.providerConfig.sttConfigs[provider.rawValue] == nil {
            model.providerConfig.sttConfigs[provider.rawValue] = ProviderEndpointConfig(
                baseURL: provider.defaultBaseURL,
                apiKey: "",
                model: provider.defaultModel
            )
        }
    }

    private func languageLabel(_ code: String) -> String {
        switch code {
        case "zh-CN": return "中文"
        case "en": return "English"
        case "ja": return "日本語"
        case "ko": return "한국어"
        default: return code
        }
    }
}
