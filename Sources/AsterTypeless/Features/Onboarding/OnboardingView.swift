import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: TypelessAppModel
    @Binding var isPresented: Bool

    @State private var currentStep = 0

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
            detail: "AsterTypeless uses Accessibility APIs to insert transcribed text into the currently focused text field."
        ),
        OnboardingStep(
            icon: "keyboard",
            title: "Input Monitoring",
            subtitle: "Required for Fn key detection.",
            detail: "This lets us detect when you press the Fn key to start dictation. You can also use a keyboard shortcut as fallback."
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
                    .frame(maxWidth: 360)

                // Permission status for steps 1-3
                if currentStep >= 1 && currentStep <= 3 {
                    permissionStatus
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
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
        .frame(width: 480, height: 420)
        .background(AppTheme.backgroundTop)
    }

    private var stepIconColor: Color {
        switch currentStep {
        case 0: return AppTheme.accent
        case 1: return model.permissions.microphone == .granted ? AppTheme.success : AppTheme.warning
        case 2: return model.permissions.accessibility == .granted ? AppTheme.success : AppTheme.warning
        case 3: return model.permissions.inputMonitoring == .granted ? AppTheme.success : AppTheme.warning
        case 4: return AppTheme.success
        default: return AppTheme.accent
        }
    }

    private var actionButtonTitle: String {
        switch currentStep {
        case 0: return "Continue"
        case 1:
            return model.permissions.microphone == .granted ? "Next" : "Grant Microphone"
        case 2:
            return model.permissions.accessibility == .granted ? "Next" : "Open System Settings"
        case 3:
            return model.permissions.inputMonitoring == .granted ? "Next" : "Open System Settings"
        default: return "Next"
        }
    }

    @ViewBuilder
    private var permissionStatus: some View {
        let state: PermissionState = {
            switch currentStep {
            case 1: return model.permissions.microphone
            case 2: return model.permissions.accessibility
            case 3: return model.permissions.inputMonitoring
            default: return .required
            }
        }()

        HStack(spacing: 8) {
            Circle()
                .fill(state == .granted ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(state == .granted ? "Permission granted" : "Permission needed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(state == .granted ? AppTheme.success : AppTheme.warning)
        }
        .padding(.top, 8)
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
                withAnimation { currentStep += 1 }
            } else {
                model.refreshPermissions(promptAccessibility: true)
                if model.permissions.accessibility != .granted {
                    model.openSystemPrivacySettings()
                }
            }
        case 3:
            if model.permissions.inputMonitoring == .granted {
                withAnimation { currentStep += 1 }
            } else {
                model.refreshPermissions(promptInputMonitoring: true)
                if model.permissions.inputMonitoring != .granted {
                    model.openSystemPrivacySettings()
                }
            }
        default:
            withAnimation { currentStep += 1 }
        }
    }
}

private struct OnboardingStep {
    let icon: String
    let title: String
    let subtitle: String
    let detail: String
}
