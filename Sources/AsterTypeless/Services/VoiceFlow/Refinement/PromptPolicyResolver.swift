import Foundation

@MainActor
final class PromptPolicyResolver {
    func resolve(context: VoiceFlowContext, enabled: Bool) -> PromptPolicy {
        guard enabled else {
            return Self.defaultPolicy
        }

        let bundle = context.bundleIdentifier.lowercased()
        let appName = context.appName.lowercased()
        let window = context.windowTitle.lowercased()

        if matchesCodeApp(bundle: bundle, appName: appName, window: window) {
            return PromptPolicy(
                id: "code",
                title: "Code",
                styleInstruction: "输出要像开发者会直接粘贴到编辑器、代码评审或 issue 里的文字。保留技术术语，不要把变量名、命令名、接口名改写成自然语言。",
                formattingInstruction: "内联代码、命令、路径和 API 名称尽量用反引号包裹。不要额外加寒暄，不要使用 Markdown 列表，除非用户口述本身在组织列表。",
                contextInstruction: "如果上下文里包含代码或英文术语，优先保持原样。"
            )
        }

        if matchesChatApp(bundle: bundle, appName: appName) {
            return PromptPolicy(
                id: "chat",
                title: "Chat",
                styleInstruction: "输出要像可以直接发给同事或朋友的聊天消息，语气自然、轻松、不拖沓。",
                formattingInstruction: "默认使用短句，不加标题，不写解释。除非用户明显想正式表达，否则避免过度书面化。",
                contextInstruction: "如果用户选中了对话内容，保持原对话节奏。"
            )
        }

        if matchesDocumentApp(bundle: bundle, appName: appName) {
            return PromptPolicy(
                id: "document",
                title: "Document",
                styleInstruction: "输出应偏正式书面语，句子完整，逻辑顺畅，适合放进文档、邮件或知识库。",
                formattingInstruction: "尽量保持段落清晰和标点完整。除非用户明确说要口语化，否则不使用聊天语气。",
                contextInstruction: "如果周围文本已经有文档语境，沿用该语气。"
            )
        }

        return Self.defaultPolicy
    }

    private func matchesCodeApp(bundle: String, appName: String, window: String) -> Bool {
        bundle.contains("cursor")
            || bundle.contains("vscode")
            || bundle.contains("xcode")
            || appName.contains("cursor")
            || appName.contains("code")
            || window.contains(".swift")
            || window.contains(".ts")
            || window.contains(".py")
    }

    private func matchesChatApp(bundle: String, appName: String) -> Bool {
        bundle.contains("slack")
            || bundle.contains("wechat")
            || bundle.contains("feishu")
            || bundle.contains("lark")
            || appName.contains("slack")
            || appName.contains("微信")
            || appName.contains("飞书")
    }

    private func matchesDocumentApp(bundle: String, appName: String) -> Bool {
        bundle.contains("notion")
            || bundle.contains("mail")
            || bundle.contains("word")
            || bundle.contains("pages")
            || appName.contains("notion")
            || appName.contains("邮件")
            || appName.contains("word")
    }

    private static let defaultPolicy = PromptPolicy(
        id: "default",
        title: "Default",
        styleInstruction: "输出要自然、克制、可以直接发送或粘贴。",
        formattingInstruction: "只输出结果本身，不要额外解释，不要加前缀。",
        contextInstruction: "如果有选中文本或附近上下文，优先与该上下文保持一致。"
    )
}
