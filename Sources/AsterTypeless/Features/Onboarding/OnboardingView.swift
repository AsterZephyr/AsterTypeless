import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: TypelessAppModel
    @Binding var isPresented: Bool

    @State private var currentStep = 0
    @State private var refreshTimer: Timer?

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "hand.wave",
            title: "Welcome to AsterTypeless",
            subtitle: "Voice-powered input that works across any app.",
            detail: "We need a few permissions to capture your voice and write text back into the apps you use."
        ),
        OnboardingStep(
            icon: "mic.fill",
            title: "Microphone Access",
            subtitle: "Required for voice capture.",
            detail: "Your audio is processed locally or sent to your configured API provider. Nothing is stored without your knowledge."
        ),
        OnboardingStep(
            icon: "hand.raised.fill",
            title: "Accessibility",
            subtitle: "Required for writing text into other apps.",
            detail: "Open System Settings, go to Privacy & Security > Accessibility, click the '+' button, and add AsterTypeless from the Applications folder or DerivedData build output."
        ),
        OnboardingStep(
            icon: "keyboard",
            title: "Input Monitoring",
            subtitle: "Required for Fn key detection.",
            detail: "Open System Settings, go to Privacy & Security > Input Monitoring, and toggle AsterTypeless on. You can also skip this and use a keyboard shortcut instead."
        ),
        OnboardingStep(
            icon: "checkmark.seal.fill",
            title: "All Set",
            subtitle: "You're ready to start dictating.",
            detail: "Press Fn to start speaking, or use the menu bar icon. Configure your AI provider in Settings to enable real transcription."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            HStack(spacing: 6) {
                ForEach(0 ..< steps.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index <= currentStep ? AppTheme.accent : AppTheme.border.opacity(0.4))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)

            Spacer()

            // Content
            let step = steps[currentStep]

            VStack(spacing: 20) {
                Image(systemName: step.icon)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(stepIconColor)
                    .frame(height: 60)

                VStack(spacing: 8) {
                    Text(step.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text(step.subtitle)
                        .font(.body)
                        .foregroundStyle(AppTheme.muted)
                }

                Text(step.detail)
                    .font(.callout)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)

                // Permission status for steps 1-3
                if currentStep >= 1 && currentStep <= 3 {
                    permissionStatusView
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                if currentStep > 0 && currentStep < steps.count - 1 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                if currentStep >= 2 && currentStep <= 3 && currentPermissionState != .granted {
                    Button("Skip") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button(actionButtonTitle) {
                        performStepAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppTheme.accent)
                } else {
                    Button("Get Started") {
                        stopRefreshTimer()
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(AppTheme.success)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(width: 520, height: 460)
        .background(AppTheme.backgroundTop)
        .onDisappear {
            stopRefreshTimer()
        }
    }

    private var currentPermissionState: PermissionState {
        switch currentStep {
        case 1: return model.permissions.microphone
        case 2: return model.permissions.accessibility
        case 3: return model.permissions.inputMonitoring
        default: return .granted
        }
    }

    private var stepIconColor: Color {
        switch currentStep {
        case 0: return AppTheme.accent
        case 4: return AppTheme.success
        default:
            return currentPermissionState == .granted ? AppTheme.success : AppTheme.warning
        }
    }

    private var actionButtonTitle: String {
        switch currentStep {
        case 0: return "Continue"
        case 1:
            return model.permissions.microphone == .granted ? "Next" : "Grant Microphone"
        case 2:
            return model.permissions.accessibility == .granted ? "Next" : "Open Accessibility Settings"
        case 3:
            return model.permissions.inputMonitoring == .granted ? "Next" : "Open Input Monitoring Settings"
        default: return "Next"
        }
    }

    @ViewBuilder
    private var permissionStatusView: some View {
        let state = currentPermissionState

        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(state == .granted ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(state == .granted ? "Permission granted" : "Waiting for permission...")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(state == .granted ? AppTheme.success : AppTheme.warning)
            }

            if state != .granted && (currentStep == 2 || currentStep == 3) {
                Text("After enabling in System Settings, come back here. Status refreshes automatically.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
            }

            if state != .granted && currentStep == 2 {
                Text("Note: Debug builds may need to be re-added after each rebuild.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.warning)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
    }

    private func performStepAction() {
        switch currentStep {
        case 0:
            withAnimation { currentStep += 1 }
        case 1:
            if model.permissions.microphone == .granted {
                withAnimation { currentStep += 1 }
            } else {
                Task {
                    _ = await model.requestMicrophonePermission()
                    model.refreshPermissions()
                    if model.permissions.microphone == .granted {
                        withAnimation { currentStep += 1 }
                    }
                }
            }
        case 2:
            if model.permissions.accessibility == .granted {
                stopRefreshTimer()
                withAnimation { currentStep += 1 }
            } else {
                // Prompt the system dialog first
                model.refreshPermissions(promptAccessibility: true)
                // Then open the correct settings page
                model.openAccessibilitySettings()
                startRefreshTimer()
            }
        case 3:
            if model.permissions.inputMonitoring == .granted {
                stopRefreshTimer()
                withAnimation { currentStep += 1 }
            } else {
                model.refreshPermissions(promptInputMonitoring: true)
                model.openInputMonitoringSettings()
                startRefreshTimer()
            }
        default:
            withAnimation { currentStep += 1 }
        }
    }

    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            Task { @MainActor in
                model.refreshPermissions()
                if currentPermissionState == .granted {
                    stopRefreshTimer()
                    withAnimation {
                        currentStep += 1
                    }
                }
            }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

private struct OnboardingStep {
    let icon: String
    let title: String
    let subtitle: String
    let detail: String
}
