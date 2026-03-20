import Foundation

struct VoiceFlowContext: Codable, Equatable {
    var appName: String
    var bundleIdentifier: String
    var windowTitle: String
    var selectedText: String
    var surroundingText: String
    var captureMode: QuickBarCaptureMode
    var mode: QuickActionMode
    var locale: String
    var lastSuccessfulDeliveryMethod: InsertionMethod?
    var capturedAt: Date

    var displayAppName: String {
        appName.isEmpty ? "当前输入框" : appName
    }
}

struct PromptPolicy: Codable, Equatable {
    var id: String
    var title: String
    var styleInstruction: String
    var formattingInstruction: String
    var contextInstruction: String
}

struct VoiceFlowProviderSummary: Codable, Equatable {
    var preset: ModelPreset
    var llmProvider: String
    var llmModel: String
    var sttProvider: String
    var sttModel: String
}

struct VoiceFlowPersistenceUpdate {
    var session: DictationSession?
    var insertionAttempt: InsertionAttempt?
    var learnedEntries: [LexiconEntry]
}
