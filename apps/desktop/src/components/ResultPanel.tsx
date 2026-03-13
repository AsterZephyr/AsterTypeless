import type { DesktopInsertTextResult, VoiceFlowResponse } from '@typeless-open/shared'

type ResultPanelProps = {
  result: VoiceFlowResponse | null
  insertResult: DesktopInsertTextResult | null
  insertionLabel: string
  lastError: string | null
  onCopy: () => void
  onInsert: () => void
  onOpenDocs: () => void
}

function formatDelivery(kind: VoiceFlowResponse['delivery']['kind']) {
  switch (kind) {
    case 'insert-after-cursor':
      return 'Insert'
    case 'replace-selection':
      return 'Replace'
    case 'copy-only':
      return 'Copy only'
    default:
      return kind
  }
}

export function ResultPanel({
  result,
  insertResult,
  insertionLabel,
  lastError,
  onCopy,
  onInsert,
  onOpenDocs,
}: ResultPanelProps) {
  return (
    <aside className="result-panel">
      <div className="panel-header">
        <div>
          <p className="eyebrow">Output</p>
          <h2>Deliver</h2>
        </div>
        {result ? <span className="status-pill success">{result.debug.provider}</span> : null}
      </div>

      <div className="result-card">
        {lastError ? <div className="error-banner">{lastError}</div> : null}

        {result ? (
          <>
            <div className="result-meta">
              <span className="status-pill muted">{formatDelivery(result.delivery.kind)}</span>
              <span className={`status-pill ${insertResult?.ok ? 'success' : 'muted'}`}>
                {insertionLabel}
              </span>
              <span className="status-pill muted">{result.latencyMs} ms</span>
            </div>
            <div className="result-surface">
              <pre className="result-text">{result.refinedText}</pre>
            </div>
            <div className="result-actions">
              <button className="primary-button" type="button" onClick={onInsert}>
                Insert
              </button>
              <button className="ghost-button" type="button" onClick={onCopy}>
                Copy
              </button>
              <button className="ghost-button" type="button" onClick={onOpenDocs}>
                Reference
              </button>
            </div>
            <dl className="debug-grid compact-debug">
              <div>
                <dt>Source</dt>
                <dd>{result.debug.transcriptSource}</dd>
              </div>
              <div>
                <dt>Context</dt>
                <dd>{result.debug.contextDigest || 'No extra context'}</dd>
              </div>
            </dl>
          </>
        ) : (
          <div className="empty-card spacious">
            <p>Run a flow and the polished text lands here.</p>
            <span>From here you can copy it or push it back into the captured app.</span>
          </div>
        )}
      </div>
    </aside>
  )
}
