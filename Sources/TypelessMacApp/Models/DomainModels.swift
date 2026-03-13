import Foundation

enum QuickActionMode: String, CaseIterable, Codable, Identifiable {
    case dictate
    case rewrite
    case translate
    case ask

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dictate:
            return "口述"
        case .rewrite:
            return "改写"
        case .translate:
            return "翻译"
        case .ask:
            return "提问"
        }
    }

    var subtitle: String {
        switch self {
        case .dictate:
            return "把口语整理成可发送文本"
        case .rewrite:
            return "基于选中文本做润色"
        case .translate:
            return "保留语气并切换语言"
        case .ask:
            return "基于上下文快速提问"
        }
    }
}

enum PermissionState: String, Codable {
    case granted
    case required
    case unavailable

    var label: String {
        switch self {
        case .granted:
            return "已开启"
        case .required:
            return "需要权限"
        case .unavailable:
            return "不可用"
        }
    }
}

enum TranscriptFeedback: String, Codable, CaseIterable {
    case accepted
    case edited
    case retried

    var title: String {
        switch self {
        case .accepted:
            return "直接采用"
        case .edited:
            return "手动修改"
        case .retried:
            return "重新生成"
        }
    }
}

struct RuntimeSettings: Codable {
    var primaryTrigger: String = "Fn"
    var fallbackShortcut: String = "Control + Option + Space"
    var microphoneName: String = "系统默认"
    var outputLanguage: String = "English"
    var providerDisplayName: String = "OpenAI + Deepgram"
    var launchAtLogin: Bool = false
}

struct PermissionSnapshot {
    var accessibility: PermissionState = .required
    var microphone: PermissionState = .required
    var inputMonitoring: PermissionState = .required
}

struct SelectionContext {
    var focusedAppName: String = ""
    var bundleIdentifier: String = ""
    var selectedText: String = ""
    var surroundingText: String = ""
    var capturedAt: Date = .now
}

struct DictationSession: Codable, Identifiable {
    var id: UUID = UUID()
    var createdAt: Date
    var sourceAppName: String
    var mode: QuickActionMode
    var transcriptPreview: String
    var finalText: String
    var durationSeconds: Double
    var words: Int
    var savedMinutes: Double
    var feedback: TranscriptFeedback
}

struct DictationOverview {
    var totalMinutes: Int
    var totalWords: Int
    var savedMinutes: Int
    var averageWordsPerMinute: Int

    static let empty = DictationOverview(totalMinutes: 0, totalWords: 0, savedMinutes: 0, averageWordsPerMinute: 0)
}

struct PersonaReport {
    var title: String
    var summary: String
    var traits: [String]
    var suggestions: [String]

    static let placeholder = PersonaReport(
        title: "尚未生成画像",
        summary: "当你开始积累真实口述记录后，这里会逐步形成你的表达习惯与提效建议。",
        traits: ["等待数据"],
        suggestions: ["先开始几次真实口述，后续再生成长期画像。"]
    )
}

struct QuickBarState {
    var mode: QuickActionMode = .dictate
    var isPresented: Bool = false
    var isRecording: Bool = false
    var liveLevel: Double = 0
    var smoothedLevel: Double = 0
    var isSpeaking: Bool = false
    var transcriptDraft: String = ""
    var generatedText: String = ""
    var statusText: String = "按 Fn 或点击按钮开始。"
    var targetAppName: String = ""
    var targetBundleIdentifier: String = ""
    var selectedContextPreview: String = ""
    var triggerLabel: String = "Fn"
}

extension DictationSession {
    static let sampleData: [DictationSession] = [
        DictationSession(
            createdAt: .now.addingTimeInterval(-3600),
            sourceAppName: "Slack",
            mode: .dictate,
            transcriptPreview: "帮我跟设计团队说一下新的首页节奏已经确定。",
            finalText: "Hey team, the new homepage pacing is locked. I'll post the revised screenshots in the design channel shortly.",
            durationSeconds: 48,
            words: 19,
            savedMinutes: 3.2,
            feedback: .accepted
        ),
        DictationSession(
            createdAt: .now.addingTimeInterval(-7800),
            sourceAppName: "Notion",
            mode: .rewrite,
            transcriptPreview: "把这个项目说明写得更干净一点，不要那么像说明书。",
            finalText: "This project replaces the old Electron shell with a native macOS app built in SwiftUI, focused on faster dictation and tighter system integration.",
            durationSeconds: 62,
            words: 24,
            savedMinutes: 4.6,
            feedback: .edited
        ),
        DictationSession(
            createdAt: .now.addingTimeInterval(-14400),
            sourceAppName: "Mail",
            mode: .translate,
            transcriptPreview: "帮我礼貌地回复这封英文邮件，说我明天下午会补充时间。",
            finalText: "Thanks for the note. I'll send over a few time options by tomorrow afternoon so we can lock something in.",
            durationSeconds: 31,
            words: 20,
            savedMinutes: 2.0,
            feedback: .accepted
        ),
        DictationSession(
            createdAt: .now.addingTimeInterval(-86400),
            sourceAppName: "Linear",
            mode: .ask,
            transcriptPreview: "根据这个 bug 描述，帮我先写一个排查方向。",
            finalText: "Start by checking the focus and accessibility handoff when the floating panel dismisses. The regression likely lives in the transition between capture and insertion.",
            durationSeconds: 54,
            words: 24,
            savedMinutes: 3.8,
            feedback: .retried
        ),
    ]
}
