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

enum QuickBarPhase: String, Codable {
    case idle
    case armed
    case recording
    case processing
    case ready

    var title: String {
        switch self {
        case .idle:
            return "待机"
        case .armed:
            return "已就绪"
        case .recording:
            return "录音中"
        case .processing:
            return "处理中"
        case .ready:
            return "可确认"
        }
    }
}

enum QuickBarCaptureMode: String, Codable {
    case manual
    case tapToggle
    case holdToTalk
    case handsFree

    var title: String {
        switch self {
        case .manual:
            return "手动"
        case .tapToggle:
            return "单击"
        case .holdToTalk:
            return "长按"
        case .handsFree:
            return "免提"
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

enum ProviderExecutionMode: String, Codable {
    case mockReady
    case partial
    case providerReady

    var title: String {
        switch self {
        case .mockReady:
            return "Mock"
        case .partial:
            return "半配置"
        case .providerReady:
            return "可联调"
        }
    }

    var detail: String {
        switch self {
        case .mockReady:
            return "当前没有真实 key，App 会走本地占位链路。"
        case .partial:
            return "只配置了部分 provider，已经能开始接链路，但还不是完整联调态。"
        case .providerReady:
            return "Deepgram 和 OpenAI 都已具备配置，可以开始打通真实语音链路。"
        }
    }
}

struct ProviderRuntimeStatus {
    var preferredProvider: String
    var sourceDescription: String
    var sourcePath: String
    var executionMode: ProviderExecutionMode
    var openAIConfigured: Bool
    var deepgramConfigured: Bool
    var openAIBaseURL: String
    var deepgramBaseURL: String
    var openAIModel: String
    var openAITranscribeModel: String
    var deepgramModel: String
    var deepgramLanguage: String
    var lastError: String = ""

    static let mockOnly = ProviderRuntimeStatus(
        preferredProvider: "Mock",
        sourceDescription: "未读取到配置",
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

enum InsertionMethod: String, Codable {
    case accessibilityValue
    case clipboardFallback
    case failed
    case unavailable

    var title: String {
        switch self {
        case .accessibilityValue:
            return "AX 直写"
        case .clipboardFallback:
            return "剪贴板回退"
        case .failed:
            return "写回失败"
        case .unavailable:
            return "权限缺失"
        }
    }
}

struct InsertionAttempt: Codable, Identifiable {
    var id: UUID = UUID()
    var createdAt: Date
    var appName: String
    var bundleIdentifier: String
    var method: InsertionMethod
    var success: Bool
    var detail: String
}

struct InsertionCompatibilityOverview {
    var testedApps: Int
    var successfulWrites: Int
    var directWrites: Int
    var clipboardFallbacks: Int
    var failures: Int

    static let empty = InsertionCompatibilityOverview(
        testedApps: 0,
        successfulWrites: 0,
        directWrites: 0,
        clipboardFallbacks: 0,
        failures: 0
    )
}

enum ReadinessLevel: String, Codable {
    case ready
    case attention
    case blocked

    var title: String {
        switch self {
        case .ready:
            return "已就绪"
        case .attention:
            return "待完善"
        case .blocked:
            return "阻塞"
        }
    }
}

struct ReadinessItem: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var level: ReadinessLevel
}

struct ReadinessReport {
    var headline: String
    var summary: String
    var items: [ReadinessItem]
    var overallLevel: ReadinessLevel

    static let placeholder = ReadinessReport(
        headline: "正在检查当前运行状态",
        summary: "AsterTypeless 会在这里汇总权限、provider 和跨 App 能力的就绪度。",
        items: [],
        overallLevel: .attention
    )
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
    var personalizationState: String
    var tonePreset: String
    var focusApps: [String]
    var traits: [String]
    var suggestions: [String]

    static let placeholder = PersonaReport(
        title: "尚未生成画像",
        summary: "当你开始积累真实口述记录后，这里会逐步形成你的表达习惯与提效建议。",
        personalizationState: "等待样本",
        tonePreset: "Balanced",
        focusApps: [],
        traits: ["等待数据"],
        suggestions: ["先开始几次真实口述，后续再生成长期画像。"]
    )
}

struct QuickBarState {
    var mode: QuickActionMode = .dictate
    var phase: QuickBarPhase = .idle
    var captureMode: QuickBarCaptureMode = .manual
    var isPresented: Bool = false
    var isRecording: Bool = false
    var liveLevel: Double = 0
    var smoothedLevel: Double = 0
    var isSpeaking: Bool = false
    var hasDetectedSpeech: Bool = false
    var capturedDuration: Double = 0
    var transcriptDraft: String = ""
    var generatedText: String = ""
    var generatedSourceLabel: String = ""
    var statusText: String = "按 Fn 或点击按钮开始。"
    var targetAppName: String = ""
    var targetBundleIdentifier: String = ""
    var selectedContextPreview: String = ""
    var triggerLabel: String = "Fn"
    var holdDuration: Double = 0

    var isCompactLayout: Bool {
        captureMode == .holdToTalk
            && generatedText.isEmpty
            && transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (phase == .armed || phase == .recording || phase == .processing)
    }
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
