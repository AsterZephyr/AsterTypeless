import AppKit
import SwiftUI

@MainActor
final class FloatingBarWindowManager {
    private weak var model: TypelessAppModel?
    private var panel: FloatingBarPanel?

    init(model: TypelessAppModel) {
        self.model = model
    }

    func present() {
        guard let model else { return }
        let targetSize = panelSize(for: model.quickBar)

        if panel == nil {
            let panel = FloatingBarPanel(
                contentRect: NSRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.standardWindowButton(.closeButton)?.isHidden = true
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.contentView = NSHostingView(rootView: FloatingBarView(model: model))
            self.panel = panel
        } else {
            panel?.contentView = NSHostingView(rootView: FloatingBarView(model: model))
        }

        panel?.setContentSize(targetSize)
        centerPanel()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        panel?.orderOut(nil)
    }

    private func centerPanel() {
        guard let screen = NSScreen.main, let panel else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(
                x: frame.midX - (panel.frame.width / 2),
                y: frame.maxY - panel.frame.height - 70
            )
        )
    }

    private func panelSize(for quickBar: QuickBarState) -> NSSize {
        if quickBar.isCompactLayout {
            return NSSize(width: 332, height: 228)
        }

        return NSSize(width: 428, height: 430)
    }
}

final class FloatingBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
