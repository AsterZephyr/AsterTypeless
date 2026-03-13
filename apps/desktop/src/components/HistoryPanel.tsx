import type { DesktopHistoryItem } from '@typeless-open/shared'

type HistoryPanelProps = {
  history: DesktopHistoryItem[]
  onReuse: (item: DesktopHistoryItem) => void
}

export function HistoryPanel({ history, onReuse }: HistoryPanelProps) {
  return (
    <aside className="history-panel">
      <div className="panel-header">
        <div>
          <p className="eyebrow">Desktop Memory</p>
          <h2>Recent voice flows</h2>
        </div>
        <span className="status-pill muted">{history.length} saved</span>
      </div>

      <div className="history-list">
        {history.length === 0 ? (
          <div className="empty-card">
            <p>No local history yet.</p>
            <span>Run your first voice flow and it will appear here.</span>
          </div>
        ) : null}

        {history.map((item) => (
          <button
            key={item.id}
            className="history-item"
            type="button"
            onClick={() => onReuse(item)}
          >
            <div className="history-meta">
              <span>{item.mode}</span>
              <span>{new Date(item.createdAt).toLocaleTimeString()}</span>
            </div>
            <strong>{item.focusedAppName}</strong>
            <p>{item.refinedText}</p>
          </button>
        ))}
      </div>
    </aside>
  )
}

