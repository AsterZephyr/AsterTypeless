import type { VoiceFlowResponse } from '@typeless-open/shared'

type ResultPanelProps = {
  result: VoiceFlowResponse | null
  lastError: string | null
  onCopy: () => void
  onOpenDocs: () => void
}

export function ResultPanel({ result, lastError, onCopy, onOpenDocs }: ResultPanelProps) {
  return (
    <aside className="result-panel">
      <div className="panel-header">
        <div>
          <p className="eyebrow">Delivery</p>
          <h2>Polished output</h2>
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
              <span>{result.delivery.kind}</span>
              <span>{result.latencyMs} ms</span>
            </div>
            <pre className="result-text">{result.refinedText}</pre>
            <button className="primary-button" type="button" onClick={onCopy}>
              Copy output
            </button>
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
            <p>The gateway response will land here.</p>
            <span>
              Dictation, rewrite, translate, and ask mode all share the same clean-room
              contract.
            </span>
          </div>
        )}
      </div>
    </aside>
  )
}

