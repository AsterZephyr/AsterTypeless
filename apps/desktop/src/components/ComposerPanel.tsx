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

const modeCopy: Record<VoiceMode, { label: string; title: string; detail: string }> = {
  dictate: {
    label: 'Dictate',
    title: 'Speak it like you mean it',
    detail: 'Polish dictation into something you can paste into any input box.',
  },
  rewrite: {
    label: 'Rewrite',
    title: 'Rewrite the selected text',
    detail: 'Use selected context to tighten tone, clarity, and structure.',
  },
  translate: {
    label: 'Translate',
    title: 'Translate with context',
    detail: 'Keep your intent, but deliver it in the target language.',
  },
  ask: {
    label: 'Ask',
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
  const modes = Object.entries(modeCopy) as [VoiceMode, (typeof modeCopy)[VoiceMode]][]

  return (
    <section className="composer-panel">
      <div className="hero-card">
        <div className="hero-copy-block">
          <p className="eyebrow">Typeless Open</p>
          <h1>Speak, polish, paste.</h1>
          <p className="hero-copy">{copy.detail}</p>
        </div>
        <div className="hero-side">
          <span className="status-pill accent">{serverLabel}</span>
          <p className="hero-note">
            Local history stays on device. Proxy mode only forwards the current request.
          </p>
        </div>
      </div>

      <div className="mode-strip" aria-label="Voice flow mode" role="tablist">
        {modes.map(([value, item]) => (
          <button
            key={value}
            aria-selected={mode === value}
            className={`mode-button ${mode === value ? 'active' : ''}`}
            role="tab"
            type="button"
            onClick={() => onModeChange(value)}
          >
            <span>{item.label}</span>
            <small>{item.title}</small>
          </button>
        ))}
      </div>

      <div className="composer-grid">
        <div className="field-card compact">
          <label className="field-label" htmlFor="app-name">
            Focused app
          </label>
          <input
            id="app-name"
            value={focusedAppName}
            onChange={(event) => onFocusedAppNameChange(event.target.value)}
            placeholder="Slack, Notion, Linear, Gmail..."
          />
          <p className="field-hint">Later this will come from the native accessibility bridge.</p>
        </div>

        <div className="field-card compact">
          <label className="field-label" htmlFor="target-language">
            Target language
          </label>
          <input
            id="target-language"
            value={targetLanguage}
            onChange={(event) => onTargetLanguageChange(event.target.value)}
            placeholder="English"
          />
          <p className="field-hint">Used by translate mode and multilingual rewrite flows.</p>
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
            placeholder="Selected text from the current app, or a copied draft you want to rewrite."
          />
          <p className="field-hint">Clipboard is the current fallback until native selection capture lands.</p>
        </div>

        <div className="field-card">
          <label className="field-label" htmlFor="surrounding-text">
            Nearby visible text
          </label>
          <textarea
            id="surrounding-text"
            value={surroundingText}
            onChange={(event) => onSurroundingTextChange(event.target.value)}
            placeholder="Optional surrounding context from the active window."
          />
          <p className="field-hint">Helps ask mode and context-aware dictation stay on topic.</p>
        </div>

        <div className="field-card">
          <label className="field-label" htmlFor="transcript-hint">
            Transcript hint
          </label>
          <textarea
            id="transcript-hint"
            value={transcriptHint}
            onChange={(event) => onTranscriptHintChange(event.target.value)}
            placeholder="Use this to test the flow even before the real STT provider is wired in."
          />
          <p className="field-hint">Useful for fast prompt iteration without recording every time.</p>
        </div>
      </div>

      <div className="transport-card">
        <div className="transport-copy">
          <p className="field-label">Capture</p>
          <div className="transport-meta">
            <span className={`status-pill ${isRecording ? 'danger' : 'muted'}`}>
              {isRecording ? `Recording ${formatDuration(durationMs)}` : 'Ready'}
            </span>
            {hasRecordedAudio ? <span className="status-pill success">Audio attached</span> : null}
          </div>
          <p className="transport-note">
            Start with transcript hints now, then swap in a real STT provider and native insertion.
          </p>
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
