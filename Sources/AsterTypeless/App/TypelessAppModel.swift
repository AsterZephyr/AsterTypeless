import AppKit
import ApplicationServices
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
    @Published var providerConfig = ProviderConfiguration.default

    private let transcriptStore = TranscriptStore()
    private let insertionCompatibilityStore = InsertionCompatibilityStore()
    private let runtimeConfigService = RuntimeConfigService()
    private let accessibilityBridge = AccessibilityBridge()
    private let hotkeyBridge = HotkeyBridge()
    private let fallbackShortcutBridge = FallbackShortcutBridge()
    private let audioMonitor = AudioInputMonitor()
    private let providerConfigStore = ProviderConfigStore()
    private lazy var voiceFlowEngine = VoiceFlowEngine(
        contextCaptureService: ContextCaptureService(
            accessibilityBridge: accessibilityBridge,
            compatibilityStore: insertionCompatibilityStore
        ),
        deliveryService: DeliveryService(
            accessibilityBridge: accessibilityBridge,
            compatibilityStore: insertionCompatibilityStore
        )
    )
    private lazy var floatingBarManager = FloatingBarWindowManager(model: self)
    private var lastCaptureArmedAt: Date = .distantPast
    private let captureArmCooldown: TimeInterval = 0.35
    private var audioCancellables: Set<AnyCancellable> = []
    private var flowCancellables: Set<AnyCancellable> = []

    func bootstrap() {
        // Init log file first so all subsequent log() calls work
        try? "=== Pipeline Log Started ===\n".write(toFile: "/tmp/aster_pipeline.log", atomically: true, encoding: .utf8)
        Self.log("bootstrap start")
        refreshRuntimeConfiguration()
        loadProviderConfig()
        sessions = transcriptStore.loadSessions()
        insertionAttempts = insertionCompatibilityStore.loadAttempts()
        recomputeDashboard()
        refreshPermissions()
        Self.log("permissions refreshed: ax=\(permissions.accessibility) im=\(permissions.inputMonitoring) mic=\(permissions.microphone)")
        bindVoiceFlowEngine()
        refreshShortcutBindings()
        refreshQuickBarBindings()
        startHotkeyMonitoringIfPossible()
        printDiagnostics()
    }

    func printDiagnostics() {
        let lines = [
            "========== AsterTypeless Diagnostics ==========",
            "Accessibility: \(permissions.accessibility)",
            "Input Monitoring: \(permissions.inputMonitoring)",
            "Microphone: \(permissions.microphone)",
            "AXIsProcessTrusted: \(ApplicationServices.AXIsProcessTrusted())",
            "Provider: \(providerRuntime.preferredProvider)",
            "OpenAI configured: \(providerRuntime.openAIConfigured)",
            "OpenAI baseURL: \(providerRuntime.openAIBaseURL)",
            "OpenAI model: \(providerRuntime.openAIModel)",
            "STT baseURL: \(providerRuntime.deepgramBaseURL)",
            "STT model: \(providerRuntime.effectiveSTTModel)",
            "canUseOpenAI: \(providerRuntime.canUseOpenAI)",
            "canUseOpenAITranscribe: \(providerRuntime.canUseOpenAITranscribe)",
            "Execution mode: \(providerRuntime.executionMode)",
            "App path: \(Bundle.main.bundlePath)",
            "================================================",
        ]
        let text = lines.joined(separator: "\n")
        for line in lines { print(line) }
        try? text.write(toFile: "/tmp/aster_diag.txt", atomically: true, encoding: .utf8)
        Self.log("diagnostics written")
    }

    static func log(_ msg: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let ts = formatter.string(from: Date())
        let line = "[\(ts)] \(msg)\n"
        print(line, terminator: "")
        let logPath = "/tmp/aster_pipeline.log"
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        } else if let data = line.data(using: .utf8) {
            FileManager.default.createFile(atPath: logPath, contents: data)
        }
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

    func loadProviderConfig() {
        if let saved = providerConfigStore.load() {
            providerConfig = saved
            // Only override plist runtime if UI config has real endpoints
            let hasUIConfig = (saved.activeLLMConfig?.isConfigured ?? false)
                || (saved.activeSTTConfig?.isConfigured ?? false)
            if hasUIConfig {
                syncProviderConfigToRuntime()
                Self.log("loadProviderConfig: using UI config (has configured endpoints)")
            } else {
                Self.log("loadProviderConfig: UI config empty, keeping plist runtime")
            }
        } else {
            // First run: migrate from legacy plist-based config
            providerConfig = ProviderConfiguration.fromLegacy(providerRuntime)
            providerConfigStore.save(providerConfig)
            Self.log("loadProviderConfig: migrated from plist to UI config")
        }
    }

    func saveProviderConfig() {
        providerConfigStore.save(providerConfig)
        syncProviderConfigToRuntime()
        Self.log("providerConfig saved and synced to runtime")
    }

    /// Sync ProviderConfiguration (UI-managed) into ProviderRuntimeStatus (pipeline-used).
    private func syncProviderConfigToRuntime() {
        let llmConfig = providerConfig.activeLLMConfig
        let sttConfig = providerConfig.activeSTTConfig

        providerRuntime.openAIBaseURL = llmConfig?.baseURL ?? ""
        providerRuntime.openAIAPIKey = llmConfig?.apiKey ?? ""
        providerRuntime.openAIModel = llmConfig?.model ?? ""
        providerRuntime.openAIConfigured = llmConfig?.isConfigured ?? false

        providerRuntime.deepgramBaseURL = sttConfig?.baseURL ?? ""
        providerRuntime.deepgramAPIKey = sttConfig?.apiKey ?? ""
        providerRuntime.deepgramModel = sttConfig?.model ?? ""
        providerRuntime.openAITranscribeModel = sttConfig?.model ?? ""
        providerRuntime.deepgramConfigured = sttConfig?.isConfigured ?? false

        providerRuntime.deepgramLanguage = providerConfig.language
        providerRuntime.preferredProvider = providerConfig.selectedLLM.displayName

        if providerRuntime.canUseOpenAI || providerRuntime.canUseOpenAITranscribe {
            providerRuntime.executionMode = .providerReady
        } else {
            providerRuntime.executionMode = .mockReady
        }

        providerRuntime.sourceDescription = "Settings UI"
    }

    func presentQuickBar(trigger: String, captureMode: QuickBarCaptureMode = .manual) {
        voiceFlowEngine.preparePresentation(
            trigger: trigger,
            mode: quickBar.mode,
            captureMode: captureMode,
            providerConfig: providerConfig
        )
        quickBar = voiceFlowEngine.quickBar
        floatingBarManager.present()
    }

    func dismissQuickBar() {
        voiceFlowEngine.dismiss()
        audioMonitor.setStreamingCallback(nil)
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

        Self.log("startRecording: captureMode=\(quickBar.captureMode)")
        Task {
            let granted = await audioMonitor.startMonitoring()
            if granted {
                voiceFlowEngine.handleRecordingStarted(providerConfig: providerConfig)
                audioMonitor.setStreamingCallback(voiceFlowEngine.realtimeAudioConsumer)
                quickBar = voiceFlowEngine.quickBar
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
        Self.log("stopRecording called, captureMode=\(captureMode?.rawValue ?? "nil")")
        let activeCaptureMode = captureMode ?? quickBar.captureMode
        let hadSpeech = quickBar.hasDetectedSpeech
        let holdDuration = audioMonitor.elapsedSeconds

        // Collect audio before stopping the monitor
        Task { @MainActor [weak self] in
            guard let self else { return }

            let wavData = await self.audioMonitor.collectWAVData()
            Self.log("stopRecording: WAV data=\(wavData?.count ?? 0) bytes, canUseSTT=\(self.providerRuntime.canUseOpenAITranscribe)")
            self.audioMonitor.setStreamingCallback(nil)
            self.audioMonitor.stopMonitoring()
            self.quickBar.holdDuration = holdDuration

            if activeCaptureMode == .holdToTalk && !hadSpeech && self.quickBar.transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.dismissQuickBar()
                return
            }

            await self.voiceFlowEngine.stopRecording(
                wavData: wavData,
                hadSpeech: hadSpeech,
                holdDuration: holdDuration,
                settings: self.settings,
                providerRuntime: self.providerRuntime,
                providerConfig: self.providerConfig
            )
            self.quickBar = self.voiceFlowEngine.quickBar
            self.floatingBarManager.present()
        }
    }

    func runQuickAction() {
        Self.log("runQuickAction: mode=\(quickBar.mode), draft=\(quickBar.transcriptDraft.prefix(60))")
        if quickBar.transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            quickBar.transcriptDraft = quickBar.partialTranscript.isEmpty ? inferredDraft() : quickBar.partialTranscript
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.voiceFlowEngine.runQuickAction(
                settings: self.settings,
                providerRuntime: self.providerRuntime,
                providerConfig: self.providerConfig
            )
            self.quickBar = self.voiceFlowEngine.quickBar
            if self.quickBar.isPresented {
                self.floatingBarManager.present()
            } else {
                self.floatingBarManager.dismiss()
            }
        }
    }

    func retryDelivery() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.voiceFlowEngine.retryDelivery(providerConfig: self.providerConfig)
            self.quickBar = self.voiceFlowEngine.quickBar
            if self.quickBar.isPresented {
                self.floatingBarManager.present()
            } else {
                self.floatingBarManager.dismiss()
            }
        }
    }

    func copyRecoveryText() {
        guard quickBar.canCopyRecovery, !quickBar.generatedText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(quickBar.generatedText, forType: .string)
        quickBar.statusText = "结果已复制，你可以手动粘贴。"
    }

    func openSystemPrivacySettings() {
        openAccessibilitySettings()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
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

    func requestMicrophonePermission() async -> Bool {
        await audioMonitor.requestPermission()
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

    private func bindVoiceFlowEngine() {
        flowCancellables.removeAll()

        voiceFlowEngine.$quickBar
            .receive(on: RunLoop.main)
            .sink { [weak self] quickBar in
                guard let self else { return }
                self.quickBar = quickBar
                if quickBar.isPresented {
                    self.floatingBarManager.present()
                } else {
                    self.floatingBarManager.dismiss()
                }
            }
            .store(in: &flowCancellables)

        voiceFlowEngine.onPersistenceUpdate = { [weak self] update in
            guard let self else { return }
            if let session = update.session {
                self.transcriptStore.append(session)
                self.sessions = self.transcriptStore.loadSessions()
            }
            if let insertionAttempt = update.insertionAttempt {
                self.insertionCompatibilityStore.append(insertionAttempt)
                self.insertionAttempts = self.insertionCompatibilityStore.loadAttempts()
            }
            self.recomputeDashboard()
        }
    }

    private func refreshQuickBarBindings() {
        audioCancellables.removeAll()

        audioMonitor.$level
            .combineLatest(audioMonitor.$smoothedLevel, audioMonitor.$isSpeaking)
            .receive(on: RunLoop.main)
            .sink { [weak self] level, smoothedLevel, isSpeaking in
                guard let self else { return }
                self.voiceFlowEngine.syncAudioMetrics(
                    level: level,
                    smoothedLevel: smoothedLevel,
                    isSpeaking: isSpeaking,
                    elapsedSeconds: self.audioMonitor.elapsedSeconds
                )
            }
            .store(in: &audioCancellables)

        audioMonitor.$elapsedSeconds
            .receive(on: RunLoop.main)
            .sink { [weak self] elapsedSeconds in
                guard let self else { return }
                self.voiceFlowEngine.syncAudioMetrics(
                    level: self.audioMonitor.level,
                    smoothedLevel: self.audioMonitor.smoothedLevel,
                    isSpeaking: self.audioMonitor.isSpeaking,
                    elapsedSeconds: elapsedSeconds
                )
            }
            .store(in: &audioCancellables)
    }

    private func startHotkeyMonitoringIfPossible() {
        Self.log("startHotkeyMonitoringIfPossible: inputMonitoring=\(permissions.inputMonitoring)")
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

}
