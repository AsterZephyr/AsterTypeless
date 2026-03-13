import Foundation

enum QuickActionExecutionSource: String, Codable {
    case mockLocal
    case providerDeferred

    var title: String {
        switch self {
        case .mockLocal:
            return "Mock"
        case .providerDeferred:
            return "Provider-ready"
        }
    }

    var detail: String {
        switch self {
        case .mockLocal:
            return "当前没有真实 key，本次走本地 mock 链路。"
        case .providerDeferred:
            return "Provider 已具备配置，但真实网络链路还没接入，本次先走本地占位结果。"
        }
    }
}

struct QuickActionExecutionResult {
    var text: String
    var source: QuickActionExecutionSource
}

@MainActor
final class QuickActionEngine {
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
}
