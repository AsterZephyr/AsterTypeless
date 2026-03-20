import Foundation

struct DeliveryOutcome {
    var insertionResult: AccessibilityBridge.InsertionResult
    var insertionAttempt: InsertionAttempt
}

@MainActor
final class DeliveryService {
    private let accessibilityBridge: AccessibilityBridge
    private let compatibilityStore: InsertionCompatibilityStore

    init(
        accessibilityBridge: AccessibilityBridge,
        compatibilityStore: InsertionCompatibilityStore
    ) {
        self.accessibilityBridge = accessibilityBridge
        self.compatibilityStore = compatibilityStore
    }

    func deliver(
        text: String,
        context: VoiceFlowContext,
        preferStableDelivery: Bool
    ) async -> DeliveryOutcome {
        let preferredMethod = compatibilityStore.preferredMethod(
            for: context.bundleIdentifier,
            preferStableDelivery: preferStableDelivery
        )

        let result = await accessibilityBridge.insert(
            text: text,
            preferredBundleIdentifier: context.bundleIdentifier,
            preferredMethod: preferredMethod
        )

        let attempt = InsertionAttempt(
            createdAt: .now,
            appName: result.appName.isEmpty ? context.displayAppName : result.appName,
            bundleIdentifier: result.bundleIdentifier.isEmpty ? context.bundleIdentifier : result.bundleIdentifier,
            method: result.method,
            success: result.success,
            detail: result.detail
        )

        return DeliveryOutcome(
            insertionResult: result,
            insertionAttempt: attempt
        )
    }
}
