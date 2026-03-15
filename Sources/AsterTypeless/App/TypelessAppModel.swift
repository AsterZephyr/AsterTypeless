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
    @Published var insertionAttempts: [InsertionAttempt] = []
    @Published var insertionOverview = InsertionCompatibilityOverview.empty
    @Published var readinessReport = ReadinessReport.placeholder
    @Published var fallbackShortcutRegistered = false
    @Published var appearanceMode: AppTheme.AppearanceMode = .system

    private let transcriptStore = TranscriptStore()
    private let insertionCompatibilityStore = InsertionCompatibilityStore()
    private let runtimeConfigService = RuntimeConfigService()
    private let quickActionEngine = QuickActionEngine()
    private let accessibilityBridge = AccessibilityBridge()
    private let hotkeyBridge = HotkeyBridge()
    private let fallbackShortcutBridge = FallbackShortcutBridge()
    private let audioMonitor = AudioInputMonitor()
    private let streamingTranscriptEngine = StreamingTranscriptEngine()
    private lazy var floatingBarManager = FloatingBarWindowManager(model: self)
    private var lastCaptureArmedAt: Date = .distantPast
    private let captureArmCooldown: TimeInterval = 0.35

    func bootstrap() {
        refreshRuntimeConfiguration()
        sessions = transcriptStore.loadSessions()
        insertionAttempts = insertionCompatibilityStore.loadAttempts()
        recomputeDashboard()
        refreshPermissions()
        refreshShortcutBindings()
        refreshQuickBarBindings()
        startHotkeyMonitoringIfPossible()
    }

    func refreshPermissions(promptAccessibility: Bool = false, promptInputMonitoring: Bool = false) {
        permissions.accessibility = accessibilityBridge.accessibilityPermission(prompt: promptAccessibility)
        permissions.inputMonitoring = hotkeyBridge.inputMonitoringPermission(prompt: promptInputMonitoring)
        audioMonitor.refreshPermissionState()
        permissions.microphone = audioMonitor.microphonePermission
        refreshReadiness()

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
        quickBar.partialTranscript = ""
        quickBar.transcriptSourceLabel = ""
        quickBar.generatedText = ""
        quickBar.generatedSourceLabel = ""
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
        quickBar.partialTranscript = ""
        quickBar.transcriptSourceLabel = ""
        streamingTranscriptEngine.stop(finalize: false)
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
                beginStreamingTranscript()
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

        // Collect audio before stopping the monitor
        Task { @MainActor [weak self] in
            guard let self else { return }

            let wavData = await self.audioMonitor.collectWAVData()
            let finalTranscript = self.streamingTranscriptEngine.stop()
            self.audioMonitor.stopMonitoring()
            self.quickBar.isRecording = false
            self.quickBar.holdDuration = holdDuration
            self.quickBar.capturedDuration = holdDuration

            if self.quickBar.transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !finalTranscript.isEmpty {
                self.quickBar.transcriptDraft = finalTranscript
            }

            if activeCaptureMode == .holdToTalk && !hadSpeech && self.quickBar.transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.dismissQuickBar()
                return
            }

            // If we have real provider and audio data, trigger transcription
            if let wavData, self.providerRuntime.canUseOpenAITranscribe {
                self.quickBar.phase = .processing
                self.quickBar.statusText = "正在转写录音..."
                self.floatingBarManager.present()
                self.streamingTranscriptEngine.start(
                    mode: self.quickBar.mode,
                    selection: SelectionContext(
                        focusedAppName: self.quickBar.targetAppName,
                        bundleIdentifier: self.quickBar.targetBundleIdentifier,
                        selectedText: self.quickBar.transcriptDraft,
                        surroundingText: self.quickBar.selectedContextPreview,
                        capturedAt: .now
                    ),
                    providerRuntime: self.providerRuntime
                ) { [weak self] update in
                    guard let self else { return }
                    self.quickBar.partialTranscript = update.text
                    self.quickBar.transcriptSourceLabel = update.source.title
                    if update.isFinal && !update.text.isEmpty && !update.text.starts(with: "正在") && !update.text.starts(with: "转写失败") && !update.text.starts(with: "未检测") {
                        self.quickBar.transcriptDraft = update.text
                        self.quickBar.phase = .ready
                        self.quickBar.statusText = self.statusTextForStop(captureMode: activeCaptureMode, hadSpeech: hadSpeech)
                        self.floatingBarManager.present()
                    }
                }
                self.streamingTranscriptEngine.transcribeAudio(wavData: wavData)
            } else {
                self.quickBar.phase = .ready
                self.quickBar.statusText = self.statusTextForStop(captureMode: activeCaptureMode, hadSpeech: hadSpeech)
                self.floatingBarManager.present()
            }
        }
    }

    func runQuickAction() {
        quickBar.phase = .processing
        if quickBar.transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            quickBar.transcriptDraft = quickBar.partialTranscript.isEmpty ? inferredDraft() : quickBar.partialTranscript
        }

        let mode = quickBar.mode
        let draft = quickBar.transcriptDraft
        let currentSettings = settings
        let runtime = providerRuntime
        let context = SelectionContext(
            focusedAppName: quickBar.targetAppName,
            bundleIdentifier: quickBar.targetBundleIdentifier,
            selectedText: quickBar.transcriptDraft,
            surroundingText: quickBar.selectedContextPreview,
            capturedAt: .now
        )

        Task { @MainActor [weak self] in
            guard let self else { return }

            let execution: QuickActionExecutionResult
            if runtime.canUseOpenAI {
                self.quickBar.statusText = "正在通过 OpenAI 生成结果..."
                execution = await self.quickActionEngine.executeAsync(
                    mode: mode,
                    draft: draft,
                    settings: currentSettings,
                    providerRuntime: runtime,
                    context: context
                )
            } else {
                execution = self.quickActionEngine.execute(
                    mode: mode,
                    draft: draft,
                    settings: currentSettings,
                    providerRuntime: runtime
                )
            }

            self.quickBar.generatedText = execution.text
            self.quickBar.generatedSourceLabel = execution.source.title
            self.quickBar.phase = .ready
            self.quickBar.statusText = "正在把结果写回到 \(self.quickBar.targetAppName.isEmpty ? "当前输入框" : self.quickBar.targetAppName)…"

            let sessionSnapshot = DictationSession(
                createdAt: .now,
                sourceAppName: self.quickBar.targetAppName,
                mode: self.quickBar.mode,
                transcriptPreview: self.quickBar.transcriptDraft,
                finalText: self.quickBar.generatedText,
                durationSeconds: self.effectiveCapturedDuration,
                words: self.quickBar.generatedText.split(whereSeparator: \.isWhitespace).count,
                savedMinutes: max(1, Double(self.quickBar.generatedText.count) / 38),
                feedback: .accepted
            )

            let generatedText = self.quickBar.generatedText
            let targetBundleIdentifier = self.quickBar.targetBundleIdentifier
            let targetAppName = self.quickBar.targetAppName

            self.floatingBarManager.dismiss()

            let insertionResult = await self.accessibilityBridge.insert(
                text: generatedText,
                preferredBundleIdentifier: targetBundleIdentifier
            )

            let insertionAttempt = InsertionAttempt(
                createdAt: .now,
                appName: insertionResult.appName.isEmpty ? targetAppName : insertionResult.appName,
                bundleIdentifier: insertionResult.bundleIdentifier.isEmpty ? targetBundleIdentifier : insertionResult.bundleIdentifier,
                method: insertionResult.method,
                success: insertionResult.success,
                detail: insertionResult.detail
            )

            self.insertionCompatibilityStore.append(insertionAttempt)
            self.insertionAttempts = self.insertionCompatibilityStore.loadAttempts()
            self.transcriptStore.append(sessionSnapshot)
            self.sessions = self.transcriptStore.loadSessions()
            self.recomputeDashboard()
            self.dismissQuickBar()
        }
    }

    func openSystemPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func cycleAppearance() {
        let modes = AppTheme.AppearanceMode.allCases
        if let index = modes.firstIndex(of: appearanceMode) {
            appearanceMode = modes[(index + 1) % modes.count]
        } else {
            appearanceMode = .system
        }
        AppTheme.apply(appearance: appearanceMode)
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
        refreshReadiness()
    }

    func refreshShortcutBindings() {
        fallbackShortcutRegistered = fallbackShortcutBridge.register(shortcut: settings.fallbackShortcut) { [weak self] in
            Task { @MainActor in
                self?.handleFallbackShortcut()
            }
        }
        refreshReadiness()
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
                self.streamingTranscriptEngine.updateSpeechActivity(isSpeaking: isSpeaking)
                if isSpeaking {
                    self.quickBar.hasDetectedSpeech = true
                }
            }
            .store(in: &cancellables)

        audioMonitor.$elapsedSeconds
            .receive(on: RunLoop.main)
            .sink { [weak self] elapsedSeconds in
                guard let self else { return }
                if self.quickBar.isRecording {
                    self.quickBar.capturedDuration = elapsedSeconds
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

        guard canBeginCapture(mode: .tapToggle) else {
            return
        }

        presentQuickBar(trigger: "Fn", captureMode: .tapToggle)
        startRecording(captureMode: .tapToggle)
    }

    private func handleFallbackShortcut() {
        if quickBar.captureMode == .tapToggle && quickBar.isRecording {
            stopRecording(for: .tapToggle)
            return
        }

        guard canBeginCapture(mode: .tapToggle) else {
            return
        }

        presentQuickBar(trigger: settings.fallbackShortcut, captureMode: .tapToggle)
        startRecording(captureMode: .tapToggle)
    }

    private func handleFnDoubleTap() {
        if quickBar.captureMode == .handsFree && quickBar.isRecording {
            stopRecording(for: .handsFree)
            return
        }

        guard canBeginCapture(mode: .handsFree) else {
            return
        }

        presentQuickBar(trigger: "Fn", captureMode: .handsFree)
        startRecording(captureMode: .handsFree)
    }

    private func handleFnHoldStart() {
        guard canBeginCapture(mode: .holdToTalk) else {
            return
        }

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
        let tonePreset: String

        if editedCount > acceptedCount {
            tonePreset = "Detailed"
        } else if overview.averageWordsPerMinute > 110 {
            tonePreset = "Concise"
        } else {
            tonePreset = "Balanced"
        }

        personaReport = PersonaReport(
            title: "你的 Personalization 摘要",
            summary: "你更偏向把口语先快速说出来，再让系统整理成更克制、更像文字的输出，常见场景集中在 \(dominantApps.joined(separator: "、"))。",
            personalizationState: sessions.isEmpty ? "等待真实样本" : "本地画像已启用",
            tonePreset: tonePreset,
            focusApps: dominantApps,
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

        let testedApps = Set(insertionAttempts.map(\.bundleIdentifier).filter { !$0.isEmpty }).count
        let directWrites = insertionAttempts.filter { $0.method == .accessibilityValue }.count
        let clipboardFallbacks = insertionAttempts.filter { $0.method == .clipboardFallback }.count
        let failures = insertionAttempts.filter { !$0.success }.count

        insertionOverview = InsertionCompatibilityOverview(
            testedApps: testedApps,
            successfulWrites: insertionAttempts.filter(\.success).count,
            directWrites: directWrites,
            clipboardFallbacks: clipboardFallbacks,
            failures: failures
        )

        refreshReadiness()
    }

    private func inferredDraft() -> String {
        if !quickBar.partialTranscript.isEmpty {
            return quickBar.partialTranscript
        }

        if !quickBar.selectedContextPreview.isEmpty {
            return quickBar.selectedContextPreview
        }

        return "请根据当前上下文生成一版更自然、更适合发送的文本。"
    }

    private func canBeginCapture(mode: QuickBarCaptureMode) -> Bool {
        if quickBar.phase == .processing || quickBar.isRecording {
            return false
        }

        if quickBar.isPresented && quickBar.phase == .armed && quickBar.captureMode == mode {
            return false
        }

        let now = Date()
        guard now.timeIntervalSince(lastCaptureArmedAt) >= captureArmCooldown else {
            return false
        }

        lastCaptureArmedAt = now
        return true
    }

    private func beginStreamingTranscript() {
        let selection = SelectionContext(
            focusedAppName: quickBar.targetAppName,
            bundleIdentifier: quickBar.targetBundleIdentifier,
            selectedText: quickBar.transcriptDraft,
            surroundingText: quickBar.selectedContextPreview,
            capturedAt: .now
        )

        streamingTranscriptEngine.start(
            mode: quickBar.mode,
            selection: selection,
            providerRuntime: providerRuntime
        ) { [weak self] update in
            guard let self else { return }
            self.quickBar.partialTranscript = update.text
            self.quickBar.transcriptSourceLabel = update.source.title

            if self.quickBar.isRecording {
                self.quickBar.transcriptDraft = update.text
            }

            if update.isFinal, !update.text.isEmpty {
                self.quickBar.transcriptDraft = update.text
            }
        }
    }

    private func refreshReadiness() {
        let permissionItems = [
            readinessItem(
                title: "辅助功能",
                detail: permissions.accessibility == .granted ? "当前可以读取选中文本并尝试直接写回输入框。" : "未开启时无法稳定读取焦点输入框，也无法做 Typeless 式直写。",
                state: permissions.accessibility
            ),
            readinessItem(
                title: "麦克风",
                detail: permissions.microphone == .granted ? "录音和音频抖动反馈都可正常工作。" : "未开启时只能停留在浮窗原型，不能真正口述。",
                state: permissions.microphone
            ),
            readinessItem(
                title: "Fn 监听",
                detail: permissions.inputMonitoring == .granted
                    ? "可以继续打磨 tap / hold / double tap 语义。"
                    : (fallbackShortcutRegistered ? "Fn 原生体验暂时不可用，但你仍可通过 \(settings.fallbackShortcut) 这条全局热键唤起浮窗。" : "未开启时 Fn 原生体验不会生效，当前也还没有成功绑定回退快捷键。"),
                state: permissions.inputMonitoring
            ),
        ]

        let fallbackItem = ReadinessItem(
            title: "回退快捷键",
            detail: fallbackShortcutRegistered
                ? "已注册全局快捷键 \(settings.fallbackShortcut)，可以作为 Fn 的稳定回退入口。"
                : "当前没有把 \(settings.fallbackShortcut) 成功注册成全局热键，需要检查快捷键格式或系统占用情况。",
            level: fallbackShortcutRegistered ? .ready : .attention
        )

        let providerItem = ReadinessItem(
            title: "Provider 链路",
            detail: providerRuntime.executionMode.detail,
            level: providerRuntime.executionMode == .providerReady ? .ready : .attention
        )

        let insertionItem = ReadinessItem(
            title: "跨 App 写回",
            detail: insertionOverview.testedApps == 0
                ? "还没有真实兼容性样本，接下来要开始验证 Cursor、VS Code、Slack、Notion 和浏览器输入框。"
                : "已积累 \(insertionOverview.testedApps) 个 App 的样本，其中 \(insertionOverview.directWrites) 次 AX 直写，\(insertionOverview.clipboardFallbacks) 次剪贴板回退。",
            level: insertionOverview.testedApps == 0 ? .attention : (insertionOverview.failures == 0 ? .ready : .attention)
        )

        let items = permissionItems + [fallbackItem, providerItem, insertionItem]
        let blockedCount = items.filter { $0.level == .blocked }.count
        let attentionCount = items.filter { $0.level == .attention }.count

        let overallLevel: ReadinessLevel
        let headline: String
        let summary: String

        if blockedCount > 0 {
            overallLevel = .blocked
            headline = "离 Typeless 体验还差关键权限"
            summary = "先把权限和系统桥接打通，浮窗、Fn 和跨 App 直写才会真正像一个 macOS 输入工具。"
        } else if attentionCount > 0 {
            overallLevel = .attention
            headline = "主链路已可演进，但还有待补齐"
            summary = "原生交互骨架已经在路上，下一步重点是补 provider 联调和兼容性样本，而不是继续堆大页面。"
        } else {
            overallLevel = .ready
            headline = "当前已经具备完整联调前提"
            summary = "权限、provider 和跨 App 样本都已具备，接下来可以直接打通真实语音链路。"
        }

        readinessReport = ReadinessReport(
            headline: headline,
            summary: summary,
            items: items,
            overallLevel: overallLevel
        )
    }

    private func readinessItem(title: String, detail: String, state: PermissionState) -> ReadinessItem {
        let level: ReadinessLevel
        switch state {
        case .granted:
            level = .ready
        case .required:
            level = .blocked
        case .unavailable:
            level = .attention
        }

        return ReadinessItem(title: title, detail: detail, level: level)
    }

    private var cancellables: Set<AnyCancellable> = []
}
