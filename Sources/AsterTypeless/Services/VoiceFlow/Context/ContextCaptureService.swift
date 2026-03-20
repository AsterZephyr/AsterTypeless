import Foundation

@MainActor
final class ContextCaptureService {
    private let accessibilityBridge: AccessibilityBridge
    private let compatibilityStore: InsertionCompatibilityStore

    init(
        accessibilityBridge: AccessibilityBridge,
        compatibilityStore: InsertionCompatibilityStore
    ) {
        self.accessibilityBridge = accessibilityBridge
        self.compatibilityStore = compatibilityStore
    }

    func capture(
        mode: QuickActionMode,
        captureMode: QuickBarCaptureMode,
        locale: String,
        preferStableDelivery: Bool
    ) -> VoiceFlowContext {
        let selection = accessibilityBridge.captureSelectionContext()
        let windowTitle = accessibilityBridge.focusedWindowTitle()
        let preferredMethod = compatibilityStore.preferredMethod(
            for: selection.bundleIdentifier,
            preferStableDelivery: preferStableDelivery
        )

        return VoiceFlowContext(
            appName: selection.focusedAppName,
            bundleIdentifier: selection.bundleIdentifier,
            windowTitle: windowTitle,
            selectedText: selection.selectedText,
            surroundingText: selection.surroundingText,
            captureMode: captureMode,
            mode: mode,
            locale: locale,
            lastSuccessfulDeliveryMethod: preferredMethod,
            capturedAt: .now
        )
    }
}
