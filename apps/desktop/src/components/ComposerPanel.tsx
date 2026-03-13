import type { DesktopNativeStatus, VoiceMode } from '@typeless-open/shared'

type ComposerPanelProps = {
  mode: VoiceMode
  focusedAppName: string
  selectedText: string
  surroundingText: string
  transcriptHint: string
  targetLanguage: string
  serverLabel: string
  nativeStatus: DesktopNativeStatus | null
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
  onReadSelection: () => void
  onRefreshNativeStatus: () => void
  onPromptAccessibilityPermission: () => void
  onStartRecording: () => void
  onStopRecording: () => void
  onClearAudio: () => void
  onSubmit: () => void
}

const modeCopy: Record<VoiceMode, { label: string; title: string; detail: string }> = {
  dictate: {
    label: 'Dictate',
    title: 'Speech to text',
    detail: 'Polish spoken text into something ready to send.',
  },
  rewrite: {
    label: 'Rewrite',
    title: 'Tighten text',
    detail: 'Use selected context to tighten tone, clarity, and structure.',
  },
  translate: {
    label: 'Translate',
    title: 'Translate context',
    detail: 'Keep intent while changing language.',
  },
  ask: {
    label: 'Ask',
    title: 'Ask from context',
    detail: 'Treat nearby context as source material and answer directly.',
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
  nativeStatus,
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
  onReadSelection,
  onRefreshNativeStatus,
  onPromptAccessibilityPermission,
  onStartRecording,
  onStopRecording,
  onClearAudio,
  onSubmit,
}: ComposerPanelProps) {
  const copy = modeCopy[mode]
  const modes = Object.entries(modeCopy) as [VoiceMode, (typeof modeCopy)[VoiceMode]][]
  const nativeStatusClassName = nativeStatus
    ? nativeStatus.accessibilityTrusted
      ? 'success'
      : nativeStatus.helperAvailable
        ? 'muted'
        : 'danger'
    : 'muted'
  const nativeError = nativeStatus?.lastError.trim() ?? ''
  const nativeSummary = nativeStatus
    ? nativeStatus.accessibilityTrusted
      ? 'Accessibility connected'
      : nativeStatus.helperAvailable
        ? 'Accessibility permission required'
        : 'Native helper unavailable'
    : 'Checking native bridge'
  const nativeDetail = nativeStatus
    ? nativeStatus.focusedAppName
      ? `Frontmost app: ${nativeStatus.focusedAppName}`
      : nativeError
        ? nativeError
      : nativeStatus.helperAvailable
        ? 'Grant accessibility access so the app can inspect the focused window.'
        : 'The native helper only builds on macOS with Swift tools available.'
    : 'The desktop shell is checking the native bridge now.'

  return (
    <section className="composer-panel">
      <div className="composer-overview">
        <div>
          <p className="eyebrow">Compose</p>
          <h1>{copy.label}</h1>
          <p className="composer-summary">{copy.detail}</p>
        </div>
        <div className="composer-meta">
          <span className="status-pill accent">{serverLabel}</span>
          <span className="status-pill muted">{focusedAppName || 'Any app'}</span>
        </div>
      </div>

      <div className="native-status-card">
        <div className="native-status-copy">
          <div className="native-status-header">
            <p className="field-label">Native bridge</p>
            <span className={`status-pill ${nativeStatusClassName}`}>{nativeSummary}</span>
          </div>
          <p className="native-status-detail">{nativeDetail}</p>
          <p className="field-hint">Selection capture and direct insertion depend on this bridge.</p>
        </div>
        <div className="native-status-actions">
          <button className="ghost-button" type="button" onClick={onRefreshNativeStatus}>
            Refresh
          </button>
          <button
            className="ghost-button"
            type="button"
            onClick={onPromptAccessibilityPermission}
            disabled={nativeStatus?.accessibilityTrusted}
          >
            {nativeStatus?.accessibilityTrusted ? 'Enabled' : 'Enable access'}
          </button>
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
          <p className="field-hint">Usually filled from the native bridge.</p>
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
          <p className="field-hint">Used in translate mode.</p>
        </div>

        <div className="field-card wide">
          <div className="field-label-row">
            <label className="field-label" htmlFor="selected-text">
              Selected text
            </label>
            <button className="ghost-button" type="button" onClick={onReadSelection}>
              Capture
            </button>
          </div>
          <textarea
            id="selected-text"
            value={selectedText}
            onChange={(event) => onSelectedTextChange(event.target.value)}
            placeholder="Selected text from the current app, or a copied draft you want to rewrite."
          />
          <p className="field-hint">
            Native capture first, clipboard fallback if unavailable.
          </p>
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
          <p className="field-hint">Optional nearby context for ask and rewrite.</p>
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
          <p className="field-hint">You can type here instead of recording.</p>
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
          <p className="transport-note">Record audio or type directly, then run the flow.</p>
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
