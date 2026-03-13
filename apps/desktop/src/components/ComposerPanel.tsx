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
  triggerLabel: string
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
  onPromptListenEventAccess: () => void
  onStartRecording: () => void
  onStopRecording: () => void
  onClearAudio: () => void
  onSubmit: () => void
}

const modeCopy: Record<VoiceMode, { label: string; description: string }> = {
  dictate: {
    label: 'Dictate',
    description: 'Say it naturally, get clean text back.',
  },
  rewrite: {
    label: 'Rewrite',
    description: 'Use the current selection as the source.',
  },
  translate: {
    label: 'Translate',
    description: 'Preserve intent and switch language cleanly.',
  },
  ask: {
    label: 'Ask',
    description: 'Treat nearby text as source material.',
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
  triggerLabel,
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
  onPromptListenEventAccess,
  onStartRecording,
  onStopRecording,
  onClearAudio,
  onSubmit,
}: ComposerPanelProps) {
  const currentMode = modeCopy[mode]
  const modes = Object.entries(modeCopy) as [VoiceMode, (typeof modeCopy)[VoiceMode]][]
  const nativeReady = Boolean(nativeStatus?.accessibilityTrusted)
  const nativeSummary = nativeReady
    ? 'Selection and direct insertion are ready.'
    : nativeStatus?.helperAvailable
      ? 'Enable Accessibility to read and write into the focused field.'
      : 'Native helper is unavailable, so the app will stay in safe fallback mode.'
  const fnSummary = nativeStatus?.fnTriggerEnabled
    ? 'Fn can summon the quick bar globally.'
    : nativeStatus?.listenEventAccess
      ? 'Fn permission is present. The watcher will take over when it is active.'
      : 'Enable Input Monitoring if you want a real Fn trigger instead of only the shortcut.'

  return (
    <section className="composer-panel">
      <div className="composer-toolbar">
        <div className="toolbar-copy">
          <p className="eyebrow">Compose</p>
          <h1>Voice keyboard</h1>
          <p className="composer-summary">{currentMode.description}</p>
        </div>
        <div className="composer-meta">
          <span className="status-pill accent">{serverLabel}</span>
          <span className={`status-pill ${nativeStatus?.fnTriggerEnabled ? 'success' : 'muted'}`}>
            {triggerLabel}
          </span>
          <span className="status-pill muted">{focusedAppName || 'Any app'}</span>
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
            <small>{item.description}</small>
          </button>
        ))}
      </div>

      <div className="native-strip">
        <div className="native-cluster">
          <div className="native-line">
            <span className={`status-pill ${nativeReady ? 'success' : 'muted'}`}>
              {nativeReady ? 'Accessibility ready' : 'Accessibility needed'}
            </span>
            <span className={`status-pill ${nativeStatus?.fnTriggerEnabled ? 'success' : 'muted'}`}>
              {triggerLabel}
            </span>
          </div>
          <p className="native-status-detail">{nativeSummary}</p>
          <p className="field-hint">{fnSummary}</p>
        </div>
        <div className="native-actions">
          <button className="ghost-button" type="button" onClick={onReadSelection}>
            Capture
          </button>
          <button className="ghost-button" type="button" onClick={onRefreshNativeStatus}>
            Refresh
          </button>
          <button
            className="ghost-button"
            type="button"
            onClick={onPromptAccessibilityPermission}
            disabled={nativeStatus?.accessibilityTrusted}
          >
            {nativeStatus?.accessibilityTrusted ? 'AX enabled' : 'Enable AX'}
          </button>
          <button
            className="ghost-button"
            type="button"
            onClick={onPromptListenEventAccess}
            disabled={nativeStatus?.listenEventAccess}
          >
            {nativeStatus?.listenEventAccess ? 'Fn enabled' : 'Enable Fn'}
          </button>
        </div>
      </div>

      <div className="composer-layout">
        <div className="field-card primary-field">
          <div className="field-label-row">
            <label className="field-label" htmlFor="transcript-hint">
              Prompt or transcript
            </label>
            <span className="field-badge">{modeCopy[mode].label}</span>
          </div>
          <textarea
            id="transcript-hint"
            value={transcriptHint}
            onChange={(event) => onTranscriptHintChange(event.target.value)}
            placeholder="Type a rough thought, or record and let the flow clean it up."
          />
          <p className="field-hint">
            This is the main working area. In floating mode it is what you type into directly.
          </p>
        </div>

        <div className="composer-side">
          <div className="field-card side-field">
            <div className="field-label-row">
              <label className="field-label" htmlFor="selected-text">
                Selected text
              </label>
              <button className="ghost-button mini" type="button" onClick={onReadSelection}>
                Refresh
              </button>
            </div>
            <textarea
              id="selected-text"
              value={selectedText}
              onChange={(event) => onSelectedTextChange(event.target.value)}
              placeholder="Selection from the target app."
            />
          </div>

          <div className="field-card side-field">
            <label className="field-label" htmlFor="surrounding-text">
              Nearby context
            </label>
            <textarea
              id="surrounding-text"
              value={surroundingText}
              onChange={(event) => onSurroundingTextChange(event.target.value)}
              placeholder="Optional nearby text from the active window."
            />
          </div>
        </div>
      </div>

      <div className="inline-fields">
        <div className="field-card compact">
          <label className="field-label" htmlFor="app-name">
            Target app
          </label>
          <input
            id="app-name"
            value={focusedAppName}
            onChange={(event) => onFocusedAppNameChange(event.target.value)}
            placeholder="Slack, Notion, Mail..."
          />
        </div>

        <div className="field-card compact">
          <label className="field-label" htmlFor="target-language">
            Language
          </label>
          <input
            id="target-language"
            value={targetLanguage}
            onChange={(event) => onTargetLanguageChange(event.target.value)}
            placeholder="English"
          />
        </div>
      </div>

      <div className="transport-card compact-transport">
        <div className="transport-copy">
          <div className="transport-meta">
            <span className={`status-pill ${isRecording ? 'danger' : 'muted'}`}>
              {isRecording ? `Recording ${formatDuration(durationMs)}` : 'Idle'}
            </span>
            {hasRecordedAudio ? <span className="status-pill success">Audio ready</span> : null}
          </div>
          <p className="transport-note">
            Use recording when you want the full Typeless feel. Use typing when you are iterating on prompts.
          </p>
          {recordError ? <p className="transport-error">{recordError}</p> : null}
        </div>

        <div className="transport-actions">
          {isRecording ? (
            <button className="primary-button" type="button" onClick={onStopRecording}>
              Stop
            </button>
          ) : (
            <button className="primary-button" type="button" onClick={onStartRecording}>
              Record
            </button>
          )}

          <button
            className="ghost-button"
            type="button"
            onClick={onClearAudio}
            disabled={!hasRecordedAudio}
          >
            Clear
          </button>

          <button className="launch-button" type="button" onClick={onSubmit} disabled={isSubmitting}>
            {isSubmitting ? 'Running…' : 'Run flow'}
          </button>
        </div>
      </div>
    </section>
  )
}
