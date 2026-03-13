import type { DesktopHistoryItem } from '@typeless-open/shared'

type HistoryPanelProps = {
  history: DesktopHistoryItem[]
  onReuse: (item: DesktopHistoryItem) => void
}

function formatMode(mode: DesktopHistoryItem['mode']) {
  return mode.charAt(0).toUpperCase() + mode.slice(1)
}

export function HistoryPanel({ history, onReuse }: HistoryPanelProps) {
  const recentHistory = history.slice(0, 6)

  return (
    <aside className="history-panel">
      <div className="panel-header">
        <div>
          <p className="eyebrow">History</p>
          <h2>Recent</h2>
        </div>
        <span className="status-pill muted">{history.length} items</span>
      </div>

      <div className="history-list">
        {history.length === 0 ? (
          <div className="empty-card">
            <p>No local history yet.</p>
            <span>Each run is stored on device so you can quickly reuse an older draft.</span>
          </div>
        ) : null}

        {recentHistory.map((item) => (
          <button
            key={item.id}
            className="history-item"
            type="button"
            onClick={() => onReuse(item)}
          >
            <div className="history-meta">
              <span className="history-mode">{formatMode(item.mode)}</span>
              <span>{new Date(item.createdAt).toLocaleTimeString()}</span>
            </div>
            <strong>{item.focusedAppName}</strong>
            <p>{item.inputPreview}</p>
            <span className="history-secondary">{item.provider} · {item.latencyMs} ms</span>
          </button>
        ))}
      </div>
    </aside>
  )
}
