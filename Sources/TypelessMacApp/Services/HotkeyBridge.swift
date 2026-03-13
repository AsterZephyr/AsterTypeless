import AppKit
import CoreGraphics
import Foundation

@MainActor
final class HotkeyBridge {
    struct FnMonitorHandlers {
        let onTap: () -> Void
        let onDoubleTap: () -> Void
        let onHoldStart: () -> Void
        let onHoldEnd: (TimeInterval) -> Void
    }

    private var flagsMonitor: Any?
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var fnIsDown = false
    private var fnChorded = false
    private var holdStarted = false
    private var fnPressedAt: TimeInterval = 0
    private var pendingTapWorkItem: DispatchWorkItem?
    private var holdWorkItem: DispatchWorkItem?
    private let holdThreshold: TimeInterval = 0.22
    private let doubleTapThreshold: TimeInterval = 0.28

    func inputMonitoringPermission(prompt: Bool) -> PermissionState {
        if #available(macOS 10.15, *) {
            let granted = prompt ? CGRequestListenEventAccess() : CGPreflightListenEventAccess()
            return granted ? .granted : .required
        }

        return .granted
    }

    func startMonitoring(handlers: FnMonitorHandlers) {
        stopMonitoring()

        guard inputMonitoringPermission(prompt: false) == .granted else {
            return
        }

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event, handlers: handlers)
        }

        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.markChorded()
        }

        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] _ in
            self?.markChorded()
        }
    }

    func stopMonitoring() {
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
        }
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
        if let keyUpMonitor {
            NSEvent.removeMonitor(keyUpMonitor)
        }

        flagsMonitor = nil
        keyDownMonitor = nil
        keyUpMonitor = nil
        fnIsDown = false
        fnChorded = false
        holdStarted = false
        fnPressedAt = 0
        holdWorkItem?.cancel()
        holdWorkItem = nil
    }

    private func handleFlagsChanged(_ event: NSEvent, handlers: FnMonitorHandlers) {
        let fnActive = event.modifierFlags.contains(.function)
        let hasOtherModifiers = !event.modifierFlags.intersection([.command, .control, .option, .shift, .capsLock]).isEmpty

        if fnActive && !fnIsDown {
            guard !hasOtherModifiers else {
                fnIsDown = true
                fnChorded = true
                holdStarted = false
                fnPressedAt = ProcessInfo.processInfo.systemUptime
                return
            }

            fnIsDown = true
            fnChorded = false
            holdStarted = false
            fnPressedAt = ProcessInfo.processInfo.systemUptime
            scheduleHoldStart(handlers: handlers)
            return
        }

        if !fnActive && fnIsDown {
            let elapsed = ProcessInfo.processInfo.systemUptime - fnPressedAt
            let shouldTrigger = !fnChorded
            holdWorkItem?.cancel()
            holdWorkItem = nil
            let wasHold = holdStarted
            fnIsDown = false
            fnChorded = false
            holdStarted = false
            fnPressedAt = 0

            if shouldTrigger {
                if wasHold {
                    handlers.onHoldEnd(elapsed)
                } else {
                    registerTap(handlers: handlers)
                }
            }
        }
    }

    private func markChorded() {
        if fnIsDown {
            fnChorded = true
            holdWorkItem?.cancel()
            holdWorkItem = nil
        }
    }

    private func scheduleHoldStart(handlers: FnMonitorHandlers) {
        holdWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.fnIsDown, !self.fnChorded else { return }
            self.holdStarted = true
            handlers.onHoldStart()
        }
        holdWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold, execute: workItem)
    }

    private func registerTap(handlers: FnMonitorHandlers) {
        if let pendingTapWorkItem {
            pendingTapWorkItem.cancel()
            self.pendingTapWorkItem = nil
            handlers.onDoubleTap()
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingTapWorkItem = nil
            handlers.onTap()
        }
        pendingTapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapThreshold, execute: workItem)
    }
}
