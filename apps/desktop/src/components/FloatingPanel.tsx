import type { VoiceFlowResponse, VoiceMode } from '@typeless-open/shared'

type FloatingPanelProps = {
  mode: VoiceMode
  transcriptHint: string
  serverLabel: string
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
  transcriptHint,
  serverLabel,
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

  return (
    <div className="floating-shell">
      <div className="floating-header">
        <div>
          <p className="eyebrow">Quick Input</p>
          <h2>Voice prompt</h2>
        </div>
        <button className="ghost-button" type="button" onClick={onOpenMain}>
          Open workspace
        </button>
      </div>

      <div className="floating-status">
        <span className="status-pill accent">{serverLabel}</span>
        <span className={`status-pill ${isRecording ? 'danger' : 'muted'}`}>
          {isRecording ? `Recording ${formatDuration(durationMs)}` : 'Ready'}
        </span>
        {hasRecordedAudio ? <span className="status-pill success">Audio attached</span> : null}
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
        className="floating-textarea"
        value={transcriptHint}
        onChange={(event) => onTranscriptHintChange(event.target.value)}
        placeholder="Type a draft, or start speaking."
      />

      {recordError ? <p className="transport-error">{recordError}</p> : null}
      {lastError ? <p className="transport-error">{lastError}</p> : null}

      <div className="floating-actions">
        {isRecording ? (
          <button className="primary-button" type="button" onClick={onStopRecording}>
            Stop
          </button>
        ) : (
          <button className="primary-button" type="button" onClick={onStartRecording}>
            Record
          </button>
        )}

        <button className="launch-button" type="button" onClick={onSubmit} disabled={isSubmitting}>
          {isSubmitting ? 'Running...' : 'Run'}
        </button>
      </div>

      {result ? (
        <div className="floating-result">
          <strong>{modeLabels[result.mode]}</strong>
          <p>{result.refinedText}</p>
        </div>
      ) : (
        <p className="floating-note">
          Use the global shortcut to summon this bar anywhere, then type or speak into it.
        </p>
      )}
    </div>
  )
}
