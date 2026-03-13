import AppKit
import Combine
import Foundation

@MainActor
final class TypelessAppModel: ObservableObject {
    @Published var settings = RuntimeSettings()
    @Published var permissions = PermissionSnapshot()
    @Published var sessions: [DictationSession] = []
    @Published var overview = DictationOverview.empty
    @Published var personaReport = PersonaReport.placeholder
    @Published var quickBar = QuickBarState()

    private let transcriptStore = TranscriptStore()
    private let accessibilityBridge = AccessibilityBridge()
    private let hotkeyBridge = HotkeyBridge()
    private let audioMonitor = AudioInputMonitor()
    private lazy var floatingBarManager = FloatingBarWindowManager(model: self)

    func bootstrap() {
        sessions = transcriptStore.loadSessions()
        recomputeDashboard()
        refreshPermissions()
        refreshQuickBarBindings()

        hotkeyBridge.startMonitoring { [weak self] in
            Task { @MainActor in
                self?.presentQuickBar(trigger: "Fn")
            }
        }
    }

    func refreshPermissions(promptAccessibility: Bool = false, promptInputMonitoring: Bool = false) {
        permissions.accessibility = accessibilityBridge.accessibilityPermission(prompt: promptAccessibility)
        permissions.inputMonitoring = hotkeyBridge.inputMonitoringPermission(prompt: promptInputMonitoring)
        audioMonitor.refreshPermissionState()
        permissions.microphone = audioMonitor.microphonePermission

        if permissions.inputMonitoring == .granted {
            hotkeyBridge.startMonitoring { [weak self] in
                Task { @MainActor in
                    self?.presentQuickBar(trigger: "Fn")
                }
            }
        }
    }

    func presentQuickBar(trigger: String) {
        let selection = accessibilityBridge.captureSelectionContext()

        quickBar.isPresented = true
        quickBar.triggerLabel = trigger
        quickBar.targetAppName = selection.focusedAppName.isEmpty ? "任意输入框" : selection.focusedAppName
        quickBar.targetBundleIdentifier = selection.bundleIdentifier
        quickBar.selectedContextPreview = selection.selectedText.isEmpty ? selection.surroundingText : selection.selectedText
        quickBar.transcriptDraft = selection.selectedText
        quickBar.generatedText = ""
        quickBar.statusText = trigger == "Fn" ? "已捕获目标输入框，开始说话即可。" : "已打开快速口述条。"

        floatingBarManager.present()
    }

    func dismissQuickBar() {
        quickBar.isPresented = false
        quickBar.isRecording = false
        audioMonitor.stopMonitoring()
        floatingBarManager.dismiss()
    }

    func startRecording() {
        Task {
            let granted = await audioMonitor.startMonitoring()
            if granted {
                quickBar.isRecording = true
                quickBar.statusText = "正在听你说话…"
            } else {
                refreshPermissions()
                quickBar.statusText = "麦克风权限不可用，请先开启权限。"
            }
        }
    }

    func stopRecording() {
        audioMonitor.stopMonitoring()
        quickBar.isRecording = false
        quickBar.statusText = quickBar.transcriptDraft.isEmpty ? "录音结束，可以直接运行。" : "已停止录音，可以继续编辑文本。"
    }

    func runQuickAction() {
        if quickBar.transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            quickBar.transcriptDraft = inferredDraft()
        }

        quickBar.generatedText = generateOutput()
        quickBar.statusText = "已生成结果，正在准备写回。"

        _ = accessibilityBridge.insert(
            text: quickBar.generatedText,
            preferredBundleIdentifier: quickBar.targetBundleIdentifier
        )

        let session = DictationSession(
            createdAt: .now,
            sourceAppName: quickBar.targetAppName,
            mode: quickBar.mode,
            transcriptPreview: quickBar.transcriptDraft,
            finalText: quickBar.generatedText,
            durationSeconds: audioMonitor.elapsedSeconds,
            words: quickBar.generatedText.split(whereSeparator: \.isWhitespace).count,
            savedMinutes: max(1, Double(quickBar.generatedText.count) / 38),
            feedback: .accepted
        )

        transcriptStore.append(session)
        sessions = transcriptStore.loadSessions()
        recomputeDashboard()
        dismissQuickBar()
    }

    func openSystemPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func requestAccessibilityPermission() {
        refreshPermissions(promptAccessibility: true)
    }

    func requestInputMonitoringPermission() {
        refreshPermissions(promptInputMonitoring: true)
    }

    private func refreshQuickBarBindings() {
        cancellables.removeAll()

        audioMonitor.$level
            .combineLatest(audioMonitor.$smoothedLevel, audioMonitor.$isSpeaking)
            .receive(on: RunLoop.main)
            .sink { [weak self] level, smoothedLevel, isSpeaking in
                guard let self else { return }
                self.quickBar.liveLevel = level
                self.quickBar.smoothedLevel = smoothedLevel
                self.quickBar.isSpeaking = isSpeaking
            }
            .store(in: &cancellables)
    }

    private func recomputeDashboard() {
        let totalSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        let totalWords = sessions.reduce(0) { $0 + $1.words }
        let savedMinutes = sessions.reduce(0) { $0 + Int($1.savedMinutes.rounded()) }
        let averageWordsPerMinute: Int

        if totalSeconds > 0 {
            averageWordsPerMinute = Int((Double(totalWords) / totalSeconds) * 60)
        } else {
            averageWordsPerMinute = 0
        }

        overview = DictationOverview(
            totalMinutes: Int((totalSeconds / 60).rounded()),
            totalWords: totalWords,
            savedMinutes: savedMinutes,
            averageWordsPerMinute: averageWordsPerMinute
        )

        let editedCount = sessions.filter { $0.feedback == .edited }.count
        let acceptedCount = sessions.filter { $0.feedback == .accepted }.count
        let dominantApps = Dictionary(grouping: sessions, by: \.sourceAppName)
            .sorted { $0.value.count > $1.value.count }
            .prefix(3)
            .map(\.key)

        personaReport = PersonaReport(
            title: "你的口述画像",
            summary: "你更偏向把口语先快速说出来，再让系统整理成更克制、更像文字的输出，常见场景集中在 \(dominantApps.joined(separator: "、"))。",
            traits: [
                acceptedCount >= editedCount ? "偏好一次成稿" : "偏好再润色",
                overview.averageWordsPerMinute > 110 ? "语速较快" : "语速平稳",
                dominantApps.first.map { "\($0) 高频场景" } ?? "场景待积累",
            ],
            suggestions: [
                "把首页做成概览页，减少操作型表单的打扰。",
                "优先补实时音频反馈，让浮窗在说话时更有生命力。",
                "把最近转录与反馈入口拆开，降低首页信息噪音。",
            ]
        )
    }

    private func inferredDraft() -> String {
        if !quickBar.selectedContextPreview.isEmpty {
            return quickBar.selectedContextPreview
        }

        return "请根据当前上下文生成一版更自然、更适合发送的文本。"
    }

    private func generateOutput() -> String {
        let base = quickBar.transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        switch quickBar.mode {
        case .dictate:
            return base.isEmpty ? "The quick dictation result will appear here." : base
        case .rewrite:
            return "把这段内容整理得更利落一些：\(base)"
        case .translate:
            return "Translate to \(settings.outputLanguage): \(base)"
        case .ask:
            return "基于当前上下文，建议先从目标输入框、权限状态和写回链路这三处开始排查。"
        }
    }

    private var cancellables: Set<AnyCancellable> = []
}
