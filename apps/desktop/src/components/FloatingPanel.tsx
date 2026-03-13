import type { VoiceFlowResponse, VoiceMode } from '@typeless-open/shared'
import { useEffect, useRef } from 'react'

type FloatingPanelProps = {
  mode: VoiceMode
  focusedAppName: string
  transcriptHint: string
  serverLabel: string
  nativeLabel: string
  triggerLabel: string
  isRecording: boolean
  durationMs: number
  hasRecordedAudio: boolean
  recordError: string | null
  isSubmitting: boolean
  result: VoiceFlowResponse | null
  lastError: string | null
  onModeChange: (value: VoiceMode) => void
  onTranscriptHintChange: (value: string) => void
  onStartRecording: () => void
  onStopRecording: () => void
  onSubmit: () => void
  onOpenMain: () => void
}

const modeLabels: Record<VoiceMode, string> = {
  dictate: 'Dictate',
  rewrite: 'Rewrite',
  translate: 'Translate',
  ask: 'Ask',
}

function formatDuration(durationMs: number) {
  const seconds = Math.floor(durationMs / 1000)
  const milliseconds = Math.floor((durationMs % 1000) / 100)
  return `${seconds}.${milliseconds}s`
}

export function FloatingPanel({
  mode,
  focusedAppName,
  transcriptHint,
  serverLabel,
  nativeLabel,
  triggerLabel,
  isRecording,
  durationMs,
  hasRecordedAudio,
  recordError,
  isSubmitting,
  result,
  lastError,
  onModeChange,
  onTranscriptHintChange,
  onStartRecording,
  onStopRecording,
  onSubmit,
  onOpenMain,
}: FloatingPanelProps) {
  const modes = Object.entries(modeLabels) as [VoiceMode, string][]
  const textareaRef = useRef<HTMLTextAreaElement | null>(null)

  useEffect(() => {
    textareaRef.current?.focus()
    textareaRef.current?.select()
  }, [focusedAppName, mode])

  return (
    <div className="floating-shell">
      <div className="floating-header">
        <div className="floating-copy">
          <p className="eyebrow">Quick bar</p>
          <h2>{focusedAppName || 'Anywhere input'}</h2>
        </div>
        <button className="ghost-button mini" type="button" onClick={onOpenMain}>
          Open app
        </button>
      </div>

      <div className="floating-status">
        <span className="status-pill accent">{serverLabel}</span>
        <span className={`status-pill ${isRecording ? 'danger' : 'muted'}`}>
          {isRecording ? `Recording ${formatDuration(durationMs)}` : triggerLabel}
        </span>
        {hasRecordedAudio ? <span className="status-pill success">Audio</span> : null}
      </div>

      <div className="floating-modes" role="tablist" aria-label="Quick mode switch">
        {modes.map(([value, label]) => (
          <button
            key={value}
            aria-selected={mode === value}
            className={`floating-mode-button ${mode === value ? 'active' : ''}`}
            role="tab"
            type="button"
            onClick={() => onModeChange(value)}
          >
            {label}
          </button>
        ))}
      </div>

      <textarea
        ref={textareaRef}
        className="floating-textarea"
        value={transcriptHint}
        onChange={(event) => onTranscriptHintChange(event.target.value)}
        placeholder="Type or speak. Press Run to push it back into the last app."
      />

      {recordError ? <p className="transport-error">{recordError}</p> : null}
      {lastError ? <p className="transport-error">{lastError}</p> : null}

      <div className="floating-actions">
        {isRecording ? (
          <button className="primary-button" type="button" onClick={onStopRecording}>
            Stop
          </button>
        ) : (
          <button className="ghost-button" type="button" onClick={onStartRecording}>
            Record
          </button>
        )}

        <button className="launch-button" type="button" onClick={onSubmit} disabled={isSubmitting}>
          {isSubmitting ? 'Running…' : 'Run'}
        </button>
      </div>

      {result ? (
        <div className="floating-result">
          <strong>{modeLabels[result.mode]}</strong>
          <p>{result.refinedText}</p>
        </div>
      ) : (
        <p className="floating-note">{nativeLabel}. Use Fn or the shortcut to summon this bar.</p>
      )}
    </div>
  )
}
