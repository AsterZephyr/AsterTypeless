import Foundation

@MainActor
final class VoiceFlowEngine: ObservableObject {
    @Published private(set) var quickBar = QuickBarState()

    var onPersistenceUpdate: ((VoiceFlowPersistenceUpdate) -> Void)?

    private let contextCaptureService: ContextCaptureService
    private let promptPolicyResolver = PromptPolicyResolver()
    private let transcriptPostProcessor = TranscriptPostProcessor()
    private let deliveryService: DeliveryService
    private let quickActionEngine = QuickActionEngine()
    private let transcriptionCoordinator = VoiceFlowTranscriptionCoordinator()
    private let lexiconStore = LexiconStore()

    private var currentContext: VoiceFlowContext?
    private var currentRawTranscript = ""
    private var currentNormalizedTranscript = ""
    private var currentPolicy = PromptPolicy(
        id: "default",
        title: "Default",
        styleInstruction: "",
        formattingInstruction: "",
        contextInstruction: ""
    )
    private var currentProviderSummary = VoiceFlowProviderSummary(
        preset: .universal,
        llmProvider: "",
        llmModel: "",
        sttProvider: "",
        sttModel: ""
    )

    init(
        contextCaptureService: ContextCaptureService,
        deliveryService: DeliveryService
    ) {
        self.contextCaptureService = contextCaptureService
        self.deliveryService = deliveryService
    }

    var realtimeAudioConsumer: ((Data) -> Void)? {
        transcriptionCoordinator.audioConsumer
    }

    func preparePresentation(
        trigger: String,
        mode: QuickActionMode,
        captureMode: QuickBarCaptureMode,
        providerConfig: ProviderConfiguration
    ) {
        let context = contextCaptureService.capture(
            mode: mode,
            captureMode: captureMode,
            locale: providerConfig.language,
            preferStableDelivery: providerConfig.preferStableDelivery
        )
        currentContext = context
        currentPolicy = promptPolicyResolver.resolve(context: context, enabled: providerConfig.contextAwarenessEnabled)
        currentProviderSummary = providerConfig.providerSummary

        quickBar.mode = mode
        quickBar.isPresented = true
        quickBar.phase = .armed
        quickBar.captureMode = captureMode
        quickBar.triggerLabel = trigger
        quickBar.targetAppName = context.displayAppName
        quickBar.targetBundleIdentifier = context.bundleIdentifier
        quickBar.selectedContextPreview = context.selectedText.isEmpty ? context.surroundingText : context.selectedText
        quickBar.transcriptDraft = captureMode == .holdToTalk ? "" : context.selectedText
        quickBar.partialTranscript = ""
        quickBar.transcriptSourceLabel = ""
        quickBar.generatedText = ""
        quickBar.generatedSourceLabel = ""
        quickBar.statusText = statusTextForPresentation(trigger: trigger, captureMode: captureMode)
        quickBar.hasDetectedSpeech = false
        quickBar.deliveryFailureDetail = ""
        quickBar.canRetryDelivery = false
        quickBar.canCopyRecovery = false
    }

    func handleRecordingStarted(providerConfig: ProviderConfiguration) {
        quickBar.isRecording = true
        quickBar.phase = .recording
        quickBar.statusText = statusTextForRecording(captureMode: quickBar.captureMode)
        quickBar.transcriptSourceLabel = providerConfig.selectedSTT.supportsRealtimeStreaming ? "实时转写" : ""
        transcriptionCoordinator.startRealtimeIfAvailable(providerConfig: providerConfig) { [weak self] text, isFinal in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.quickBar.partialTranscript = text
                self.quickBar.transcriptSourceLabel = "Deepgram"
                self.quickBar.hasDetectedSpeech = self.quickBar.hasDetectedSpeech || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if self.quickBar.transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.quickBar.isRecording {
                    self.quickBar.transcriptDraft = text
                }
                if isFinal {
                    self.quickBar.transcriptDraft = text
                }
            }
        } onError: { [weak self] message in
            Task { @MainActor [weak self] in
                self?.quickBar.statusText = message
            }
        }
    }

    func syncAudioMetrics(level: Double, smoothedLevel: Double, isSpeaking: Bool, elapsedSeconds: Double) {
        quickBar.liveLevel = level
        quickBar.smoothedLevel = smoothedLevel
        quickBar.isSpeaking = isSpeaking
        quickBar.capturedDuration = elapsedSeconds
        if isSpeaking {
            quickBar.hasDetectedSpeech = true
        }
    }

    func stopRecording(
        wavData: Data?,
        hadSpeech: Bool,
        holdDuration: Double,
        settings: RuntimeSettings,
        providerRuntime: ProviderRuntimeStatus,
        providerConfig: ProviderConfiguration
    ) async {
        quickBar.isRecording = false
        quickBar.holdDuration = holdDuration
        quickBar.capturedDuration = max(quickBar.capturedDuration, holdDuration)
        quickBar.phase = .processing
        quickBar.statusText = "正在转写录音..."

        let realtimeText = await transcriptionCoordinator.stopRealtime()

        if let context = currentContext, !realtimeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            currentRawTranscript = realtimeText
            await continueWithTranscriptionResult(
                transcript: realtimeText,
                wavData: wavData,
                hadSpeech: hadSpeech,
                settings: settings,
                providerRuntime: providerRuntime,
                providerConfig: providerConfig,
                context: context
            )
            return
        }

        guard let wavData, let context = currentContext else {
            quickBar.phase = .ready
            quickBar.statusText = hadSpeech ? "录音结束，可以继续编辑文本。" : "没有检测到明显语音，你可以继续手动输入。"
            return
        }

        do {
            let lexiconHint = lexiconStore.promptHint(for: context)
            let transcript = try await transcriptionCoordinator.transcribeBatch(
                wavData: wavData,
                providerRuntime: providerRuntime,
                providerConfig: providerConfig,
                context: context,
                lexiconHint: lexiconHint
            )
            await continueWithTranscriptionResult(
                transcript: transcript,
                wavData: wavData,
                hadSpeech: hadSpeech,
                settings: settings,
                providerRuntime: providerRuntime,
                providerConfig: providerConfig,
                context: context
            )
        } catch {
            quickBar.phase = .ready
            quickBar.statusText = "转写失败：\(error.localizedDescription)"
            quickBar.deliveryFailureDetail = quickBar.statusText
            quickBar.canCopyRecovery = true
        }
    }

    func runQuickAction(
        settings: RuntimeSettings,
        providerRuntime: ProviderRuntimeStatus,
        providerConfig: ProviderConfiguration
    ) async {
        guard let context = currentContext else { return }

        let draft = quickBar.transcriptDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty else {
            quickBar.phase = .ready
            quickBar.statusText = "没有可处理的文本，可以继续编辑。"
            return
        }

        quickBar.phase = .processing
        quickBar.statusText = providerRuntime.canUseOpenAI ? "正在生成结果..." : "正在使用本地占位结果..."
        currentPolicy = promptPolicyResolver.resolve(context: context, enabled: providerConfig.contextAwarenessEnabled)

        let execution = await quickActionEngine.executeAsync(
            mode: quickBar.mode,
            draft: draft,
            settings: settings,
            providerRuntime: providerRuntime,
            context: context,
            policy: currentPolicy
        )

        quickBar.generatedText = execution.text
        quickBar.generatedSourceLabel = execution.source.title
        quickBar.phase = .ready
        quickBar.statusText = "正在把结果写回到 \(context.displayAppName)…"

        let outcome = await deliveryService.deliver(
            text: execution.text,
            context: context,
            preferStableDelivery: providerConfig.preferStableDelivery
        )

        let session = DictationSession(
            createdAt: .now,
            sourceAppName: context.displayAppName,
            mode: quickBar.mode,
            transcriptPreview: currentRawTranscript.isEmpty ? draft : currentRawTranscript,
            finalText: execution.text,
            durationSeconds: max(quickBar.capturedDuration, holdDurationFallback),
            words: execution.text.split(whereSeparator: \.isWhitespace).count,
            savedMinutes: max(1, Double(execution.text.count) / 38),
            feedback: outcome.insertionAttempt.success ? .accepted : .edited,
            rawTranscript: currentRawTranscript,
            normalizedTranscript: currentNormalizedTranscript.isEmpty ? draft : currentNormalizedTranscript,
            contextSnapshot: context,
            providerSummary: currentProviderSummary,
            deliveryResult: outcome.insertionAttempt,
            accepted: outcome.insertionAttempt.success
        )

        let learned = providerConfig.lexiconLearningEnabled
            ? lexiconStore.learn(rawText: currentRawTranscript, acceptedText: execution.text, context: context)
            : []

        onPersistenceUpdate?(
            VoiceFlowPersistenceUpdate(
                session: session,
                insertionAttempt: outcome.insertionAttempt,
                learnedEntries: learned
            )
        )

        if outcome.insertionAttempt.success {
            dismiss()
        } else {
            quickBar.phase = .ready
            quickBar.statusText = outcome.insertionAttempt.detail
            quickBar.deliveryFailureDetail = outcome.insertionAttempt.detail
            quickBar.canRetryDelivery = true
            quickBar.canCopyRecovery = true
        }
    }

    func retryDelivery(providerConfig: ProviderConfiguration) async {
        guard quickBar.canRetryDelivery, let context = currentContext, !quickBar.generatedText.isEmpty else { return }
        quickBar.phase = .processing
        quickBar.statusText = "正在重试写回..."

        let outcome = await deliveryService.deliver(
            text: quickBar.generatedText,
            context: context,
            preferStableDelivery: providerConfig.preferStableDelivery
        )

        onPersistenceUpdate?(
            VoiceFlowPersistenceUpdate(
                session: nil,
                insertionAttempt: outcome.insertionAttempt,
                learnedEntries: []
            )
        )

        if outcome.insertionAttempt.success {
            dismiss()
        } else {
            quickBar.phase = .ready
            quickBar.statusText = outcome.insertionAttempt.detail
            quickBar.deliveryFailureDetail = outcome.insertionAttempt.detail
            quickBar.canRetryDelivery = true
            quickBar.canCopyRecovery = true
        }
    }

    func dismiss() {
        transcriptionCoordinator.cancelRealtime()
        currentContext = nil
        currentRawTranscript = ""
        currentNormalizedTranscript = ""
        let preservedMode = quickBar.mode
        quickBar = QuickBarState()
        quickBar.mode = preservedMode
    }

    private var holdDurationFallback: Double {
        quickBar.holdDuration > 0 ? quickBar.holdDuration : quickBar.capturedDuration
    }

    private func continueWithTranscriptionResult(
        transcript: String,
        wavData: Data?,
        hadSpeech: Bool,
        settings: RuntimeSettings,
        providerRuntime: ProviderRuntimeStatus,
        providerConfig: ProviderConfiguration,
        context: VoiceFlowContext
    ) async {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        currentRawTranscript = trimmed

        guard !trimmed.isEmpty else {
            quickBar.phase = .ready
            quickBar.statusText = hadSpeech ? "没有得到有效转写结果，可以继续编辑。" : "没有检测到明显语音，你可以继续手动输入。"
            return
        }

        let processed = transcriptPostProcessor.process(
            rawText: trimmed,
            context: context,
            lexicon: lexiconStore.entries(for: context)
        )
        currentNormalizedTranscript = processed.normalizedText
        quickBar.partialTranscript = trimmed
        quickBar.transcriptSourceLabel = providerConfig.selectedSTT.displayName
        quickBar.transcriptDraft = processed.normalizedText
        quickBar.statusText = "转写完成，正在处理..."

        await runQuickAction(
            settings: settings,
            providerRuntime: providerRuntime,
            providerConfig: providerConfig
        )
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

    private func statusTextForRecording(captureMode: QuickBarCaptureMode) -> String {
        switch captureMode {
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
}
