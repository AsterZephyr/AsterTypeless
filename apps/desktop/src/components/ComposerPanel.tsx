import type { VoiceMode } from '@typeless-open/shared'

type ComposerPanelProps = {
  mode: VoiceMode
  focusedAppName: string
  selectedText: string
  surroundingText: string
  transcriptHint: string
  targetLanguage: string
  serverLabel: string
  isRecording: boolean
  durationMs: number
  hasRecordedAudio: boolean
  recordError: string | null
  isSubmitting: boolean
  onModeChange: (value: VoiceMode) => void
  onFocusedAppNameChange: (value: string) => void
  onSelectedTextChange: (value: string) => void
  onSurroundingTextChange: (value: string) => void
  onTranscriptHintChange: (value: string) => void
  onTargetLanguageChange: (value: string) => void
  onReadClipboard: () => void
  onStartRecording: () => void
  onStopRecording: () => void
  onClearAudio: () => void
  onSubmit: () => void
}

const modeCopy: Record<VoiceMode, { title: string; detail: string }> = {
  dictate: {
    title: 'Speak it like you mean it',
    detail: 'Polish dictation into something you can paste into any input box.',
  },
  rewrite: {
    title: 'Rewrite the selected text',
    detail: 'Use selected context to tighten tone, clarity, and structure.',
  },
  translate: {
    title: 'Translate with context',
    detail: 'Keep your intent, but deliver it in the target language.',
  },
  ask: {
    title: 'Ask about what is on screen',
    detail: 'Treat nearby context as source material and return a direct answer.',
  },
}

function formatDuration(durationMs: number) {
  const seconds = Math.floor(durationMs / 1000)
  const milliseconds = Math.floor((durationMs % 1000) / 100)
  return `${seconds}.${milliseconds}s`
}

export function ComposerPanel({
  mode,
  focusedAppName,
  selectedText,
  surroundingText,
  transcriptHint,
  targetLanguage,
  serverLabel,
  isRecording,
  durationMs,
  hasRecordedAudio,
  recordError,
  isSubmitting,
  onModeChange,
  onFocusedAppNameChange,
  onSelectedTextChange,
  onSurroundingTextChange,
  onTranscriptHintChange,
  onTargetLanguageChange,
  onReadClipboard,
  onStartRecording,
  onStopRecording,
  onClearAudio,
  onSubmit,
}: ComposerPanelProps) {
  const copy = modeCopy[mode]

  return (
    <section className="composer-panel">
      <div className="hero-card">
        <div>
          <p className="eyebrow">Typeless Open</p>
          <h1>{copy.title}</h1>
          <p className="hero-copy">{copy.detail}</p>
        </div>
        <div className="hero-badges">
          <span className="status-pill">{serverLabel}</span>
          <span className="status-pill muted">Context-aware</span>
          <span className="status-pill muted">Clean-room build</span>
        </div>
      </div>

      <div className="composer-grid">
        <div className="field-card">
          <label className="field-label" htmlFor="mode">
            Voice flow mode
          </label>
          <select id="mode" value={mode} onChange={(event) => onModeChange(event.target.value as VoiceMode)}>
            <option value="dictate">Dictate</option>
            <option value="rewrite">Rewrite</option>
            <option value="translate">Translate</option>
            <option value="ask">Ask</option>
          </select>
        </div>

        <div className="field-card">
          <label className="field-label" htmlFor="app-name">
            Focused app
          </label>
          <input
            id="app-name"
            value={focusedAppName}
            onChange={(event) => onFocusedAppNameChange(event.target.value)}
            placeholder="Slack, Notion, Linear, Gmail..."
          />
        </div>

        <div className="field-card">
          <label className="field-label" htmlFor="target-language">
            Target language
          </label>
          <input
            id="target-language"
            value={targetLanguage}
            onChange={(event) => onTargetLanguageChange(event.target.value)}
            placeholder="English"
          />
        </div>

        <div className="field-card wide">
          <div className="field-label-row">
            <label className="field-label" htmlFor="selected-text">
              Selected text
            </label>
            <button className="ghost-button" type="button" onClick={onReadClipboard}>
              Use clipboard
            </button>
          </div>
          <textarea
            id="selected-text"
            value={selectedText}
            onChange={(event) => onSelectedTextChange(event.target.value)}
            placeholder="What the user selected or what the native accessibility layer captured."
          />
        </div>

        <div className="field-card wide">
          <label className="field-label" htmlFor="surrounding-text">
            Nearby visible text
          </label>
          <textarea
            id="surrounding-text"
            value={surroundingText}
            onChange={(event) => onSurroundingTextChange(event.target.value)}
            placeholder="Optional surrounding context from the active window."
          />
        </div>

        <div className="field-card wide">
          <label className="field-label" htmlFor="transcript-hint">
            Transcript hint
          </label>
          <textarea
            id="transcript-hint"
            value={transcriptHint}
            onChange={(event) => onTranscriptHintChange(event.target.value)}
            placeholder="Use this to test the gateway even before the native transcription path is wired up."
          />
        </div>
      </div>

      <div className="transport-card">
        <div>
          <p className="field-label">Input transport</p>
          <div className="transport-meta">
            <span className={`status-pill ${isRecording ? 'danger' : 'muted'}`}>
              {isRecording ? `Recording ${formatDuration(durationMs)}` : 'Ready'}
            </span>
            {hasRecordedAudio ? <span className="status-pill success">Audio attached</span> : null}
          </div>
          {recordError ? <p className="transport-error">{recordError}</p> : null}
        </div>

        <div className="transport-actions">
          {isRecording ? (
            <button className="primary-button" type="button" onClick={onStopRecording}>
              Stop recording
            </button>
          ) : (
            <button className="primary-button" type="button" onClick={onStartRecording}>
              Start recording
            </button>
          )}

          <button className="ghost-button" type="button" onClick={onClearAudio}>
            Clear audio
          </button>

          <button className="launch-button" type="button" onClick={onSubmit} disabled={isSubmitting}>
            {isSubmitting ? 'Running voice flow...' : 'Run voice flow'}
          </button>
        </div>
      </div>
    </section>
  )
}

