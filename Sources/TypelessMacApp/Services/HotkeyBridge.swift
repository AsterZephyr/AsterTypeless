import AppKit
import CoreGraphics
import Foundation

@MainActor
final class HotkeyBridge {
    struct FnMonitorHandlers {
        let onPress: () -> Void
        let onRelease: (TimeInterval) -> Void
    }

    private var flagsMonitor: Any?
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var fnIsDown = false
    private var fnChorded = false
    private var fnPressedAt: TimeInterval = 0

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
        fnPressedAt = 0
    }

    private func handleFlagsChanged(_ event: NSEvent, handlers: FnMonitorHandlers) {
        let fnActive = event.modifierFlags.contains(.function)
        let hasOtherModifiers = !event.modifierFlags.intersection([.command, .control, .option, .shift, .capsLock]).isEmpty

        if fnActive && !fnIsDown {
            guard !hasOtherModifiers else {
                fnIsDown = true
                fnChorded = true
                fnPressedAt = ProcessInfo.processInfo.systemUptime
                return
            }

            fnIsDown = true
            fnChorded = false
            fnPressedAt = ProcessInfo.processInfo.systemUptime
            handlers.onPress()
            return
        }

        if !fnActive && fnIsDown {
            let elapsed = ProcessInfo.processInfo.systemUptime - fnPressedAt
            let shouldTrigger = !fnChorded
            fnIsDown = false
            fnChorded = false
            fnPressedAt = 0

            if shouldTrigger {
                handlers.onRelease(elapsed)
            }
        }
    }

    private func markChorded() {
        if fnIsDown {
            fnChorded = true
        }
    }
}
