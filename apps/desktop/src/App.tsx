import {
  type DesktopCapturedContext,
  createHistoryPreview,
  type DesktopHistoryItem,
  type DesktopInsertTextResult,
  type DesktopNativeStatus,
  type DesktopRuntimeInfo,
  type VoiceGatewayRuntime,
  type VoiceFlowResponse,
  type VoiceMode,
} from '@typeless-open/shared'
import { startTransition, useDeferredValue, useEffect, useState } from 'react'

import { ComposerPanel } from './components/ComposerPanel'
import { FloatingPanel } from './components/FloatingPanel'
import { HistoryPanel } from './components/HistoryPanel'
import { ResultPanel } from './components/ResultPanel'
import { useVoiceRecorder } from './hooks/useVoiceRecorder'
import { desktopBridge } from './lib/desktop'
import { fetchVoiceRuntime, submitVoiceFlow } from './lib/server'
import './App.css'

function App() {
  const surface =
    typeof window !== 'undefined'
      ? new URLSearchParams(window.location.search).get('surface') || 'main'
      : 'main'
  const [mode, setMode] = useState<VoiceMode>('dictate')
  const [focusedAppName, setFocusedAppName] = useState('Slack')
  const [selectedText, setSelectedText] = useState('')
  const [surroundingText, setSurroundingText] = useState(
    'Standup notes, customer support threads, or current draft copy can live here as nearby context.',
  )
  const [transcriptHint, setTranscriptHint] = useState(
    'hey team I just shipped the clean room typeless MVP and the desktop skeleton is ready for review',
  )
  const [targetLanguage, setTargetLanguage] = useState('English')
  const [runtimeInfo, setRuntimeInfo] = useState<DesktopRuntimeInfo | null>(null)
  const [voiceRuntime, setVoiceRuntime] = useState<VoiceGatewayRuntime | null>(null)
  const [nativeStatus, setNativeStatus] = useState<DesktopNativeStatus | null>(null)
  const [targetBundleId, setTargetBundleId] = useState('')
  const [history, setHistory] = useState<DesktopHistoryItem[]>([])
  const [result, setResult] = useState<VoiceFlowResponse | null>(null)
  const [insertResult, setInsertResult] = useState<DesktopInsertTextResult | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [lastError, setLastError] = useState<string | null>(null)
  const recorder = useVoiceRecorder()
  const deferredResult = useDeferredValue(result)

  function applyCapturedContext(context: DesktopCapturedContext) {
    startTransition(() => {
      if (context.triggerSource !== 'manual') {
        setResult(null)
        setLastError(null)
      }
      if (context.focusedAppName) {
        setFocusedAppName(context.focusedAppName)
      }
      if (context.focusedBundleId) {
        setTargetBundleId(context.focusedBundleId)
      }
      if (context.selectedText) {
        setSelectedText(context.selectedText)
      }
      if (context.surroundingText) {
        setSurroundingText(context.surroundingText)
      }
      setInsertResult(null)
    })
  }

  useEffect(() => {
    let isActive = true

    async function hydrateShell() {
      const [runtime, savedHistory, nextNativeStatus, capturedContext] = await Promise.all([
        desktopBridge.getRuntimeInfo(),
        desktopBridge.listHistory(),
        desktopBridge.getNativeStatus(),
        desktopBridge.getLastCapturedContext(),
      ])

      if (!isActive) return

      startTransition(() => {
        setRuntimeInfo(runtime)
        setHistory(savedHistory)
        setNativeStatus(nextNativeStatus)
        if (capturedContext.focusedAppName) {
          setFocusedAppName(capturedContext.focusedAppName)
        } else if (nextNativeStatus.focusedAppName) {
          setFocusedAppName(nextNativeStatus.focusedAppName)
        }
        if (capturedContext.focusedBundleId) {
          setTargetBundleId(capturedContext.focusedBundleId)
        } else if (nextNativeStatus.focusedBundleId) {
          setTargetBundleId(nextNativeStatus.focusedBundleId)
        }
        if (capturedContext.selectedText) {
          setSelectedText(capturedContext.selectedText)
        }
        if (capturedContext.surroundingText) {
          setSurroundingText(capturedContext.surroundingText)
        }
      })

      try {
        const runtime = await fetchVoiceRuntime()
        if (!isActive) return
        setVoiceRuntime(runtime)
      } catch (error) {
        if (!isActive) return
        setVoiceRuntime(null)
        setLastError(error instanceof Error ? error.message : 'Unable to reach voice runtime')
      }
    }

    void hydrateShell()
    const unsubscribe = desktopBridge.onCapturedContext((context) => {
      if (!isActive) return
      applyCapturedContext(context)
    })

    return () => {
      isActive = false
      unsubscribe()
    }
  }, [])

  async function handleReadSelectionContext() {
    setLastError(null)

    try {
      const selection = await desktopBridge.readSelectionContext()

      startTransition(() => {
        if (selection.focusedAppName) {
          setFocusedAppName(selection.focusedAppName)
        }
        if (selection.focusedBundleId) {
          setTargetBundleId(selection.focusedBundleId)
        }
        setSelectedText(selection.selectedText)
        if (selection.surroundingText) {
          setSurroundingText(selection.surroundingText)
        }
        setInsertResult(null)
      })

      if (!selection.available && selection.lastError) {
        setLastError(selection.lastError)
      }
    } catch (error) {
      setLastError(error instanceof Error ? error.message : 'Unable to read selection context')
    }
  }

  async function handleRefreshNativeStatus() {
    setLastError(null)

    try {
      const nextNativeStatus = await desktopBridge.getNativeStatus()
      startTransition(() => {
        setNativeStatus(nextNativeStatus)
        if (nextNativeStatus.focusedAppName) {
          setFocusedAppName(nextNativeStatus.focusedAppName)
        }
        if (nextNativeStatus.focusedBundleId) {
          setTargetBundleId(nextNativeStatus.focusedBundleId)
        }
      })
    } catch (error) {
      setLastError(error instanceof Error ? error.message : 'Unable to read native helper status')
    }
  }

  async function handlePromptAccessibilityPermission() {
    setLastError(null)

    try {
      const nextNativeStatus = await desktopBridge.promptAccessibilityPermission()
      startTransition(() => {
        setNativeStatus(nextNativeStatus)
        if (nextNativeStatus.focusedAppName) {
          setFocusedAppName(nextNativeStatus.focusedAppName)
        }
        if (nextNativeStatus.focusedBundleId) {
          setTargetBundleId(nextNativeStatus.focusedBundleId)
        }
      })
    } catch (error) {
      setLastError(
        error instanceof Error ? error.message : 'Unable to prompt for accessibility permission',
      )
    }
  }

  async function handlePromptListenEventAccess() {
    setLastError(null)

    try {
      const nextNativeStatus = await desktopBridge.promptListenEventAccess()
      startTransition(() => {
        setNativeStatus(nextNativeStatus)
      })

      if (!nextNativeStatus.listenEventAccess && nextNativeStatus.lastError) {
        setLastError(nextNativeStatus.lastError)
      }
    } catch (error) {
      setLastError(
        error instanceof Error ? error.message : 'Unable to prompt for input monitoring access',
      )
    }
  }

  async function handleSubmit() {
    setIsSubmitting(true)
    setLastError(null)

    try {
      const nextResult = await submitVoiceFlow({
        mode,
        context: {
          focusedAppName,
          selectedText,
          surroundingText,
          transcriptHint,
          targetLanguage,
        },
        metadata: {
          client: 'desktop',
          durationMs: recorder.durationMs,
          mimeType: recorder.audioBlob?.type || 'audio/webm',
          source: recorder.audioBlob ? 'microphone' : 'text-hint',
        },
        audioBlob: recorder.audioBlob,
        audioFilename: recorder.audioFilename,
      })

      const historyItem: DesktopHistoryItem = {
        id: crypto.randomUUID(),
        createdAt: new Date().toISOString(),
        mode,
        focusedAppName,
        inputPreview: createHistoryPreview(transcriptHint || selectedText || surroundingText),
        refinedText: nextResult.refinedText,
        provider: nextResult.debug.provider,
        latencyMs: nextResult.latencyMs,
      }

      startTransition(() => {
        setResult(nextResult)
        setInsertResult(null)
      })

      if (surface === 'floating' && targetBundleId && nextResult.delivery.kind !== 'copy-only') {
        const nextInsertResult = await desktopBridge.insertText({
          text: nextResult.refinedText,
          preferredBundleId: targetBundleId,
        })

        startTransition(() => {
          setInsertResult(nextInsertResult)
        })

        if (nextInsertResult.ok) {
          await desktopBridge.toggleFloatingWindow()
        } else if (nextInsertResult.lastError) {
          setLastError(nextInsertResult.lastError)
        }
      }

      const savedHistory = await desktopBridge.saveHistory(historyItem)
      startTransition(() => {
        setHistory(savedHistory)
      })
    } catch (error) {
      setLastError(error instanceof Error ? error.message : 'Voice flow failed')
    } finally {
      setIsSubmitting(false)
    }
  }

  async function handleCopyOutput() {
    if (!deferredResult?.refinedText) return
    await desktopBridge.copyToClipboard(deferredResult.refinedText)
  }

  async function handleInsertOutput() {
    if (!deferredResult?.refinedText) return

    setLastError(null)

    try {
      const nextInsertResult = await desktopBridge.insertText({
        text: deferredResult.refinedText,
        preferredBundleId: targetBundleId,
      })

      setInsertResult(nextInsertResult)

      if (!nextInsertResult.ok && nextInsertResult.lastError) {
        setLastError(nextInsertResult.lastError)
      } else if (nextInsertResult.focusedAppName) {
        setFocusedAppName(nextInsertResult.focusedAppName)
      }
    } catch (error) {
      setLastError(error instanceof Error ? error.message : 'Unable to insert text into the target app')
    }
  }

  async function handleOpenDocs() {
    await desktopBridge.openExternal('https://www.typeless.com/')
  }

  async function handleOpenMainWindow() {
    await desktopBridge.showMainWindow()
  }

  function handleReuseHistory(item: DesktopHistoryItem) {
    setMode(item.mode)
    setFocusedAppName(item.focusedAppName)
    setTranscriptHint(item.refinedText)
  }

  const serverLabel = voiceRuntime
    ? `${voiceRuntime.provider} via ${voiceRuntime.transport.toUpperCase()}`
    : 'voice runtime unavailable'
  const nativeLabel = nativeStatus
    ? nativeStatus.accessibilityTrusted
      ? 'Bridge ready'
      : nativeStatus.helperAvailable
        ? 'Accessibility needed'
        : 'Native helper unavailable'
    : 'Checking native bridge'
  const triggerLabel = nativeStatus
    ? nativeStatus.fnTriggerEnabled
      ? 'Fn ready'
      : nativeStatus.listenEventAccess
        ? 'Fn watcher starting'
        : 'Shortcut fallback'
    : 'Checking trigger'
  const insertionLabel = insertResult?.ok
    ? `${insertResult.method} into ${insertResult.focusedAppName || 'target app'}`
    : targetBundleId
      ? `Ready for ${focusedAppName || 'captured app'}`
      : 'Capture a target app first'

  if (surface === 'floating') {
    return (
      <FloatingPanel
        mode={mode}
        focusedAppName={focusedAppName}
        transcriptHint={transcriptHint}
        serverLabel={serverLabel}
        nativeLabel={nativeLabel}
        triggerLabel={triggerLabel}
        isRecording={recorder.isRecording}
        durationMs={recorder.durationMs}
        hasRecordedAudio={Boolean(recorder.audioBlob)}
        recordError={recorder.error}
        isSubmitting={isSubmitting}
        result={deferredResult}
        lastError={lastError}
        onModeChange={setMode}
        onTranscriptHintChange={setTranscriptHint}
        onStartRecording={recorder.startRecording}
        onStopRecording={recorder.stopRecording}
        onSubmit={handleSubmit}
        onOpenMain={handleOpenMainWindow}
      />
    )
  }

  return (
    <div className="app-shell">
      <main className="workspace-panel">
        <header className="workspace-header">
          <div className="workspace-title">
            <p className="eyebrow">Typeless Open</p>
            <h2>Compact voice keyboard</h2>
          </div>
          <div className="header-runtime">
            <span className="status-pill">
              {runtimeInfo ? `${runtimeInfo.appName} ${runtimeInfo.appVersion}` : 'Booting shell'}
            </span>
            <span
              className={`status-pill ${
                nativeStatus?.accessibilityTrusted
                  ? 'success'
                  : nativeStatus?.helperAvailable
                    ? 'muted'
                    : 'danger'
              }`}
            >
              {nativeLabel}
            </span>
            <span className={`status-pill ${nativeStatus?.fnTriggerEnabled ? 'success' : 'muted'}`}>
              {triggerLabel}
            </span>
          </div>
        </header>

        <div className="workspace-body">
          <ComposerPanel
            mode={mode}
            focusedAppName={focusedAppName}
            selectedText={selectedText}
            surroundingText={surroundingText}
            transcriptHint={transcriptHint}
            targetLanguage={targetLanguage}
            serverLabel={serverLabel}
            nativeStatus={nativeStatus}
            triggerLabel={triggerLabel}
            isRecording={recorder.isRecording}
            durationMs={recorder.durationMs}
            hasRecordedAudio={Boolean(recorder.audioBlob)}
            recordError={recorder.error}
            isSubmitting={isSubmitting}
            onModeChange={setMode}
            onFocusedAppNameChange={setFocusedAppName}
            onSelectedTextChange={setSelectedText}
            onSurroundingTextChange={setSurroundingText}
            onTranscriptHintChange={setTranscriptHint}
            onTargetLanguageChange={setTargetLanguage}
            onReadSelection={handleReadSelectionContext}
            onRefreshNativeStatus={handleRefreshNativeStatus}
            onPromptAccessibilityPermission={handlePromptAccessibilityPermission}
            onPromptListenEventAccess={handlePromptListenEventAccess}
            onStartRecording={recorder.startRecording}
            onStopRecording={recorder.stopRecording}
            onClearAudio={recorder.clearRecording}
            onSubmit={handleSubmit}
          />

          <aside className="utility-rail">
            <ResultPanel
              result={deferredResult}
              insertResult={insertResult}
              insertionLabel={insertionLabel}
              lastError={lastError}
              onCopy={handleCopyOutput}
              onInsert={handleInsertOutput}
              onOpenDocs={handleOpenDocs}
            />
            <HistoryPanel history={history} onReuse={handleReuseHistory} />
          </aside>
        </div>
      </main>
    </div>
  )
}

export default App
