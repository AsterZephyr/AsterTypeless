import {
  createHistoryPreview,
  type DesktopHistoryItem,
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
  const [history, setHistory] = useState<DesktopHistoryItem[]>([])
  const [result, setResult] = useState<VoiceFlowResponse | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [lastError, setLastError] = useState<string | null>(null)
  const recorder = useVoiceRecorder()
  const deferredResult = useDeferredValue(result)

  useEffect(() => {
    let isActive = true

    async function hydrateShell() {
      const [runtime, savedHistory] = await Promise.all([
        desktopBridge.getRuntimeInfo(),
        desktopBridge.listHistory(),
      ])

      if (!isActive) return

      startTransition(() => {
        setRuntimeInfo(runtime)
        setHistory(savedHistory)
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

    return () => {
      isActive = false
    }
  }, [])

  async function handleReadClipboard() {
    const text = await desktopBridge.readSelectionFallback()
    setSelectedText(text)
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
      })

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

  if (surface === 'floating') {
    return (
      <FloatingPanel
        mode={mode}
        transcriptHint={transcriptHint}
        serverLabel={serverLabel}
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
      <HistoryPanel history={history} onReuse={handleReuseHistory} />

      <main className="workspace-panel">
        <header className="workspace-header">
          <div>
            <p className="eyebrow">Open-source desktop MVP</p>
            <h2>Clean-room voice keyboard with local runtime</h2>
          </div>
          <div className="header-runtime">
            <span className="status-pill">
              {runtimeInfo ? `${runtimeInfo.appName} ${runtimeInfo.appVersion}` : 'Booting shell'}
            </span>
            <span className="status-pill muted">
              {runtimeInfo ? runtimeInfo.platform : 'unknown platform'}
            </span>
          </div>
        </header>

        <ComposerPanel
          mode={mode}
          focusedAppName={focusedAppName}
          selectedText={selectedText}
          surroundingText={surroundingText}
          transcriptHint={transcriptHint}
          targetLanguage={targetLanguage}
          serverLabel={serverLabel}
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
          onReadClipboard={handleReadClipboard}
          onStartRecording={recorder.startRecording}
          onStopRecording={recorder.stopRecording}
          onClearAudio={recorder.clearRecording}
          onSubmit={handleSubmit}
        />
      </main>

      <ResultPanel
        result={deferredResult}
        lastError={lastError}
        onCopy={handleCopyOutput}
        onOpenDocs={handleOpenDocs}
      />
    </div>
  )
}

export default App
