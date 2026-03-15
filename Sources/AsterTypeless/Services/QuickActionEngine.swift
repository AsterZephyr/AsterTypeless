import Foundation

enum QuickActionExecutionSource: String, Codable {
    case mockLocal
    case providerDeferred
    case openAILive

    var title: String {
        switch self {
        case .mockLocal:
            return "Mock"
        case .providerDeferred:
            return "Provider-ready"
        case .openAILive:
            return "OpenAI"
        }
    }

    var detail: String {
        switch self {
        case .mockLocal:
            return "当前没有真实 key，本次走本地 mock 链路。"
        case .providerDeferred:
            return "Provider 已具备配置，但真实网络链路还没接入，本次先走本地占位结果。"
        case .openAILive:
            return "通过 OpenAI API 生成真实结果。"
        }
    }
}

struct QuickActionExecutionResult {
    var text: String
    var source: QuickActionExecutionSource
}

@MainActor
final class QuickActionEngine {

    /// Synchronous mock execution (fallback when no API key).
    func execute(
        mode: QuickActionMode,
        draft: String,
        settings: RuntimeSettings,
        providerRuntime: ProviderRuntimeStatus
    ) -> QuickActionExecutionResult {
        let source: QuickActionExecutionSource = providerRuntime.executionMode == .mockReady ? .mockLocal : .providerDeferred
        let base = draft.trimmingCharacters(in: .whitespacesAndNewlines)

        let text: String
        switch mode {
        case .dictate:
            text = base.isEmpty ? "The quick dictation result will appear here." : base
        case .rewrite:
            text = "把这段内容整理得更利落一些：\(base)"
        case .translate:
            text = "Translate to \(settings.outputLanguage): \(base)"
        case .ask:
            text = "基于当前上下文，建议先从目标输入框、权限状态和写回链路这三处开始排查。"
        }

        return QuickActionExecutionResult(text: text, source: source)
    }

    /// Async execution with real OpenAI API when key is available.
    func executeAsync(
        mode: QuickActionMode,
        draft: String,
        settings: RuntimeSettings,
        providerRuntime: ProviderRuntimeStatus,
        context: SelectionContext
    ) async -> QuickActionExecutionResult {
        guard providerRuntime.canUseOpenAI,
              let client = providerRuntime.makeOpenAIClient()
        else {
            return execute(mode: mode, draft: draft, settings: settings, providerRuntime: providerRuntime)
        }

        let base = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else {
            return execute(mode: mode, draft: draft, settings: settings, providerRuntime: providerRuntime)
        }

        let systemPrompt = buildSystemPrompt(mode: mode, settings: settings, context: context)
        let messages: [ChatMessage] = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: base),
        ]

        let model = providerRuntime.openAIModel.isEmpty ? "gpt-4o-mini" : providerRuntime.openAIModel

        do {
            let result = try await client.chatCompletion(
                model: model,
                messages: messages,
                temperature: 0.7
            )

            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return QuickActionExecutionResult(text: trimmed, source: .openAILive)
            } else {
                return execute(mode: mode, draft: draft, settings: settings, providerRuntime: providerRuntime)
            }
        } catch {
            // Fallback to mock on error
            var fallback = execute(mode: mode, draft: draft, settings: settings, providerRuntime: providerRuntime)
            fallback.text = "[API 调用失败，使用本地结果] \(fallback.text)"
            return fallback
        }
    }

    private func buildSystemPrompt(mode: QuickActionMode, settings: RuntimeSettings, context: SelectionContext) -> String {
        let appName = context.focusedAppName.isEmpty ? "未知 App" : context.focusedAppName
        let lang = settings.outputLanguage

        switch mode {
        case .dictate:
            return """
            你是一个语音转文字助手。用户通过语音口述了一段内容，请把它整理成更自然、更适合直接发送的文字。
            保留用户的原意和语气，修正口语化的表达，使其更流畅。
            目标 App: \(appName)
            输出语言: \(lang)
            只输出整理后的文本，不要添加任何解释或前缀。
            """
        case .rewrite:
            return """
            你是一个文本改写助手。请把用户提供的文本改写得更简洁、更利落，同时保留原意和语气。
            减少冗余表达，让文本更像专业写作而不是口语。
            目标 App: \(appName)
            输出语言: \(lang)
            只输出改写后的文本，不要添加任何解释或前缀。
            """
        case .translate:
            return """
            你是一个翻译助手。请把用户提供的内容翻译成 \(lang)。
            保持原文的语气、重点和格式。翻译要自然流畅，不要生硬直译。
            只输出翻译后的文本，不要添加任何解释或前缀。
            """
        case .ask:
            let surroundingContext = context.surroundingText.isEmpty ? "" : "\n当前附近上下文: \(String(context.surroundingText.prefix(500)))"
            return """
            你是一个智能助手。用户基于当前输入上下文提出了一个问题或请求。
            请给出简洁、有用的回答。\(surroundingContext)
            目标 App: \(appName)
            输出语言: \(lang)
            直接回答问题，不要重复问题本身。
            """
        }
    }
}
