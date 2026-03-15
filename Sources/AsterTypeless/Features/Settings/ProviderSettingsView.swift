import SwiftUI

struct ProviderSettingsView: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // LLM Provider
            VStack(alignment: .leading, spacing: 12) {
                Text("LLM Provider")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text("Used for text generation, rewriting, and translation.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                Picker("LLM", selection: $model.providerConfig.selectedLLM) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.providerConfig.selectedLLM) { _ in
                    ensureLLMConfigExists()
                    model.saveProviderConfig()
                }

                if let config = model.providerConfig.activeLLMConfig {
                    endpointEditor(
                        config: binding(for: model.providerConfig.selectedLLM),
                        provider: model.providerConfig.selectedLLM
                    )
                } else {
                    Button("Configure \(model.providerConfig.selectedLLM.displayName)") {
                        ensureLLMConfigExists()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .cardSurface()

            // STT Provider
            VStack(alignment: .leading, spacing: 12) {
                Text("STT Provider")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Text("Used for speech-to-text transcription.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)

                Picker("STT", selection: $model.providerConfig.selectedSTT) {
                    ForEach(STTProvider.allCases) { provider in
                        HStack {
                            Text(provider.displayName)
                            if provider.supportsRealtimeStreaming {
                                Text("RT")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.providerConfig.selectedSTT) { _ in
                    ensureSTTConfigExists()
                    model.saveProviderConfig()
                }

                if let config = model.providerConfig.activeSTTConfig {
                    endpointEditor(
                        sttConfig: sttBinding(for: model.providerConfig.selectedSTT),
                        provider: model.providerConfig.selectedSTT
                    )
                } else {
                    Button("Configure \(model.providerConfig.selectedSTT.displayName)") {
                        ensureSTTConfigExists()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .cardSurface()

            // Language
            VStack(alignment: .leading, spacing: 8) {
                Text("Language")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                HStack(spacing: 12) {
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

            // Status summary
            statusSummary
        }
    }

    // MARK: - LLM endpoint editor

    private func endpointEditor(config: Binding<ProviderEndpointConfig>, provider: LLMProvider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(config.wrappedValue.isConfigured ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(config.wrappedValue.isConfigured ? "Configured" : "Not configured")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }

            TextField("Base URL", text: config.baseURL)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            SecureField("API Key", text: config.apiKey)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            TextField("Model", text: config.model)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            Text(provider.setupHint)
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)

            Button("Save") {
                model.saveProviderConfig()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .insetSurface()
    }

    // MARK: - STT endpoint editor

    private func endpointEditor(sttConfig: Binding<ProviderEndpointConfig>, provider: STTProvider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(sttConfig.wrappedValue.isConfigured ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(sttConfig.wrappedValue.isConfigured ? "Configured" : "Not configured")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)

                if provider.supportsRealtimeStreaming {
                    StatusPill(title: "Real-time", tint: .green)
                }
            }

            TextField("Base URL", text: sttConfig.baseURL)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            SecureField("API Key", text: sttConfig.apiKey)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            TextField("Model", text: sttConfig.model)
                .textFieldStyle(.roundedBorder)
                .font(.caption)

            Text(provider.setupHint)
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)

            Button("Save") {
                model.saveProviderConfig()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .insetSurface()
    }

    // MARK: - Status

    private var statusSummary: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LLM")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                Text(model.providerConfig.selectedLLM.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.providerConfig.activeLLMConfig?.isConfigured == true ? AppTheme.success : AppTheme.warning)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("STT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                Text(model.providerConfig.selectedSTT.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.providerConfig.activeSTTConfig?.isConfigured == true ? AppTheme.success : AppTheme.warning)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Lang")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.muted)
                Text(model.providerConfig.language)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }

            Spacer()
        }
        .insetSurface()
    }

    // MARK: - Helpers

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

    private func binding(for provider: LLMProvider) -> Binding<ProviderEndpointConfig> {
        Binding(
            get: {
                model.providerConfig.llmConfigs[provider.rawValue] ?? ProviderEndpointConfig(
                    baseURL: provider.defaultBaseURL, apiKey: "", model: provider.defaultModel
                )
            },
            set: { model.providerConfig.llmConfigs[provider.rawValue] = $0 }
        )
    }

    private func sttBinding(for provider: STTProvider) -> Binding<ProviderEndpointConfig> {
        Binding(
            get: {
                model.providerConfig.sttConfigs[provider.rawValue] ?? ProviderEndpointConfig(
                    baseURL: provider.defaultBaseURL, apiKey: "", model: provider.defaultModel
                )
            },
            set: { model.providerConfig.sttConfigs[provider.rawValue] = $0 }
        )
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
