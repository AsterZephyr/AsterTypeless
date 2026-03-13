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
    @Published var providerRuntime = ProviderRuntimeStatus.mockOnly

    private let transcriptStore = TranscriptStore()
    private let runtimeConfigService = RuntimeConfigService()
    private let accessibilityBridge = AccessibilityBridge()
    private let hotkeyBridge = HotkeyBridge()
    private let audioMonitor = AudioInputMonitor()
    private lazy var floatingBarManager = FloatingBarWindowManager(model: self)

    func bootstrap() {
        refreshRuntimeConfiguration()
        sessions = transcriptStore.loadSessions()
        recomputeDashboard()
        refreshPermissions()
        refreshQuickBarBindings()
        startHotkeyMonitoringIfPossible()
    }

    func refreshPermissions(promptAccessibility: Bool = false, promptInputMonitoring: Bool = false) {
        permissions.accessibility = accessibilityBridge.accessibilityPermission(prompt: promptAccessibility)
        permissions.inputMonitoring = hotkeyBridge.inputMonitoringPermission(prompt: promptInputMonitoring)
        audioMonitor.refreshPermissionState()
        permissions.microphone = audioMonitor.microphonePermission

        if permissions.inputMonitoring == .granted {
            startHotkeyMonitoringIfPossible()
        } else {
            hotkeyBridge.stopMonitoring()
        }
    }

    func presentQuickBar(trigger: String, captureMode: QuickBarCaptureMode = .manual) {
        let selection = accessibilityBridge.captureSelectionContext()

        quickBar.isPresented = true
        quickBar.phase = .armed
        quickBar.captureMode = captureMode
        quickBar.triggerLabel = trigger
        quickBar.targetAppName = selection.focusedAppName.isEmpty ? "任意输入框" : selection.focusedAppName
        quickBar.targetBundleIdentifier = selection.bundleIdentifier
        quickBar.selectedContextPreview = selection.selectedText.isEmpty ? selection.surroundingText : selection.selectedText
        quickBar.transcriptDraft = captureMode == .holdToTalk ? "" : selection.selectedText
        quickBar.generatedText = ""
        quickBar.hasDetectedSpeech = false
        quickBar.capturedDuration = 0
        quickBar.holdDuration = 0
        quickBar.statusText = statusTextForPresentation(trigger: trigger, captureMode: captureMode)

        floatingBarManager.present()
    }

    func dismissQuickBar() {
        quickBar.phase = .idle
        quickBar.captureMode = .manual
        quickBar.isPresented = false
        quickBar.isRecording = false
        quickBar.hasDetectedSpeech = false
        quickBar.capturedDuration = 0
        quickBar.holdDuration = 0
        audioMonitor.stopMonitoring()
        floatingBarManager.dismiss()
    }

    func startRecording(captureMode: QuickBarCaptureMode? = nil) {
        guard !quickBar.isRecording else {
            return
        }

        if let captureMode {
            quickBar.captureMode = captureMode
        }

        Task {
            let granted = await audioMonitor.startMonitoring()
            if granted {
                quickBar.isRecording = true
                quickBar.phase = .recording
                quickBar.hasDetectedSpeech = false
                quickBar.capturedDuration = 0
                quickBar.statusText = statusTextForRecording()
                floatingBarManager.present()
            } else {
                refreshPermissions()
                quickBar.phase = .armed
                quickBar.statusText = "麦克风权限不可用，请先开启权限。"
                floatingBarManager.present()
            }
        }
    }

    func stopRecording(for captureMode: QuickBarCaptureMode? = nil) {
        let activeCaptureMode = captureMode ?? quickBar.captureMode
        let hadSpeech = quickBar.hasDetectedSpeech
        let holdDuration = audioMonitor.elapsedSeconds
        audioMonitor.stopMonitoring()
        quickBar.isRecording = false
        quickBar.holdDuration = holdDuration
        quickBar.capturedDuration = holdDuration

        if activeCaptureMode == .holdToTalk && !hadSpeech && quickBar.transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dismissQuickBar()
            return
        }

        quickBar.phase = .ready
        quickBar.statusText = statusTextForStop(captureMode: activeCaptureMode, hadSpeech: hadSpeech)
        floatingBarManager.present()
    }

    func runQuickAction() {
        quickBar.phase = .processing
        if quickBar.transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            quickBar.transcriptDraft = inferredDraft()
        }

        quickBar.generatedText = generateOutput()
        quickBar.phase = .ready
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
            durationSeconds: effectiveCapturedDuration,
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

    func refreshRuntimeConfiguration() {
        providerRuntime = runtimeConfigService.loadStatus()
        settings.providerDisplayName = "\(providerRuntime.preferredProvider) · \(providerRuntime.executionMode.title)"
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
                if isSpeaking {
                    self.quickBar.hasDetectedSpeech = true
                }
            }
            .store(in: &cancellables)
    }

    private func startHotkeyMonitoringIfPossible() {
        hotkeyBridge.startMonitoring(
            handlers: .init(
                onTap: { [weak self] in
                    Task { @MainActor in
                        self?.handleFnTap()
                    }
                },
                onDoubleTap: { [weak self] in
                    Task { @MainActor in
                        self?.handleFnDoubleTap()
                    }
                },
                onHoldStart: { [weak self] in
                    Task { @MainActor in
                        self?.handleFnHoldStart()
                    }
                },
                onHoldEnd: { [weak self] elapsed in
                    Task { @MainActor in
                        self?.handleFnHoldEnd(elapsed: elapsed)
                    }
                }
            )
        )
    }

    private func handleFnTap() {
        if quickBar.captureMode == .tapToggle && quickBar.isRecording {
            stopRecording(for: .tapToggle)
            return
        }

        if quickBar.captureMode == .handsFree && quickBar.isRecording {
            stopRecording(for: .handsFree)
            return
        }

        presentQuickBar(trigger: "Fn", captureMode: .tapToggle)
        startRecording(captureMode: .tapToggle)
    }

    private func handleFnDoubleTap() {
        if quickBar.captureMode == .handsFree && quickBar.isRecording {
            stopRecording(for: .handsFree)
            return
        }

        presentQuickBar(trigger: "Fn", captureMode: .handsFree)
        startRecording(captureMode: .handsFree)
    }

    private func handleFnHoldStart() {
        presentQuickBar(trigger: "Fn", captureMode: .holdToTalk)
        startRecording(captureMode: .holdToTalk)
    }

    private func handleFnHoldEnd(elapsed: TimeInterval) {
        quickBar.holdDuration = elapsed

        guard quickBar.captureMode == .holdToTalk else {
            return
        }

        if quickBar.isRecording {
            stopRecording(for: .holdToTalk)
        } else if quickBar.isPresented && quickBar.phase == .armed {
            dismissQuickBar()
        }
    }

    private var effectiveCapturedDuration: Double {
        if quickBar.capturedDuration > 0 {
            return quickBar.capturedDuration
        }

        if audioMonitor.elapsedSeconds > 0 {
            return audioMonitor.elapsedSeconds
        }

        return quickBar.holdDuration
    }

    private func statusTextForPresentation(trigger: String, captureMode: QuickBarCaptureMode) -> String {
        switch captureMode {
        case .manual:
            return trigger == "Fn" ? "已捕获目标输入框，开始说话即可。" : "已打开快速口述条。"
        case .tapToggle:
            return "轻点 Fn 开始，再点一次 Fn 结束。"
        case .holdToTalk:
            return "按住 Fn 说话，松开后结束本次口述。"
        case .handsFree:
            return "已进入 hands-free，再双击 Fn 可结束。"
        }
    }

    private func statusTextForRecording() -> String {
        switch quickBar.captureMode {
        case .manual:
            return "正在听你说话…"
        case .tapToggle:
            return "正在录音，再点一次 Fn 结束。"
        case .holdToTalk:
            return "松开 Fn 即可结束本次口述。"
        case .handsFree:
            return "hands-free 录音中，再双击 Fn 结束。"
        }
    }

    private func statusTextForStop(captureMode: QuickBarCaptureMode, hadSpeech: Bool) -> String {
        switch captureMode {
        case .manual:
            return quickBar.transcriptDraft.isEmpty ? "录音结束，可以直接运行。" : "已停止录音，可以继续编辑文本。"
        case .tapToggle:
            return hadSpeech ? "已结束本次录音，可以继续编辑或点击运行。" : "没有检测到明显语音，你可以继续手动输入。"
        case .holdToTalk:
            return hadSpeech ? "已结束本次口述。当前还是本地原型，可继续编辑或点击运行。" : "没有检测到明显语音，你可以继续手动输入。"
        case .handsFree:
            return hadSpeech ? "hands-free 已结束，可以继续编辑或点击运行。" : "hands-free 已结束，但没有检测到明显语音。"
        }
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
