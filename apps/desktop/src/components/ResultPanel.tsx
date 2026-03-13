import type { VoiceFlowResponse } from '@typeless-open/shared'

type ResultPanelProps = {
  result: VoiceFlowResponse | null
  lastError: string | null
  onCopy: () => void
  onOpenDocs: () => void
}

function formatDelivery(kind: VoiceFlowResponse['delivery']['kind']) {
  switch (kind) {
    case 'insert-after-cursor':
      return 'Insert after cursor'
    case 'replace-selection':
      return 'Replace selection'
    case 'copy-only':
      return 'Copy only'
    default:
      return kind
  }
}

export function ResultPanel({ result, lastError, onCopy, onOpenDocs }: ResultPanelProps) {
  return (
    <aside className="result-panel">
      <div className="panel-header">
        <div>
          <p className="eyebrow">Output</p>
          <h2>Ready to paste</h2>
        </div>
        <button className="ghost-button" type="button" onClick={onOpenDocs}>
          Docs
        </button>
      </div>

      <div className="result-card">
        {lastError ? <div className="error-banner">{lastError}</div> : null}

        {result ? (
          <>
            <div className="result-meta">
              <span className="status-pill success">{result.debug.provider}</span>
              <span className="status-pill muted">{formatDelivery(result.delivery.kind)}</span>
              <span className="status-pill muted">{result.latencyMs} ms</span>
            </div>
            <div className="result-surface">
              <pre className="result-text">{result.refinedText}</pre>
            </div>
            <div className="result-actions">
              <button className="primary-button" type="button" onClick={onCopy}>
                Copy output
              </button>
              <button className="ghost-button" type="button" onClick={onOpenDocs}>
                Open docs
              </button>
            </div>
            <dl className="debug-grid">
              <div>
                <dt>Transcript source</dt>
                <dd>{result.debug.transcriptSource}</dd>
              </div>
              <div>
                <dt>Audio</dt>
                <dd>{result.debug.audioProvided ? 'Attached' : 'Not attached'}</dd>
              </div>
              <div>
                <dt>Context digest</dt>
                <dd>{result.debug.contextDigest || 'No context'}</dd>
              </div>
            </dl>
          </>
        ) : (
          <div className="empty-card spacious">
            <p>The polished result will appear here.</p>
            <span>Run any voice flow to preview provider output, delivery mode, and debug context.</span>
          </div>
        )}
      </div>
    </aside>
  )
}
