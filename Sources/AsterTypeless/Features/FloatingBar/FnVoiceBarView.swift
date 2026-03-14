import SwiftUI

struct FnVoiceBarView: View {
    @ObservedObject var model: TypelessAppModel
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            MiniWaveStrip(level: model.quickBar.smoothedLevel, isSpeaking: model.quickBar.isSpeaking, phase: model.quickBar.phase)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.52))

                Text(displayDuration)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(0.2)
            }

            Spacer(minLength: 6)

            Button(action: primaryAction) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(isHovered ? 0.17 : 0.1))

                    Image(systemName: buttonSymbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(buttonTint)
                }
                .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .help(buttonHelp)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: 250)
        .background(
            ZStack {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.10, blue: 0.18).opacity(0.94),
                                Color(red: 0.05, green: 0.07, blue: 0.13).opacity(0.96),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppTheme.brand500.opacity(0.32), lineWidth: 1)
        )
        .shadow(color: AppTheme.brand500.opacity(0.22), radius: 28, y: 10)
        .shadow(color: Color.black.opacity(0.26), radius: 28, y: 14)
        .scaleEffect(isHovered ? 1.03 : 1)
        .animation(.spring(duration: 0.28, bounce: 0.24), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var statusLabel: String {
        switch model.quickBar.phase {
        case .armed:
            return "Listening"
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .ready:
            return "Ready"
        case .idle:
            return "Standby"
        }
    }

    private var displayDuration: String {
        let duration = max(model.quickBar.capturedDuration, model.quickBar.holdDuration)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration * 10).rounded()) % 10
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    private var buttonSymbol: String {
        switch model.quickBar.phase {
        case .recording, .processing:
            return "stop.fill"
        case .armed, .ready, .idle:
            return "xmark"
        }
    }

    private var buttonTint: Color {
        switch model.quickBar.phase {
        case .recording, .processing:
            return Color(red: 0.99, green: 0.43, blue: 0.43)
        case .armed, .ready, .idle:
            return Color.white.opacity(0.82)
        }
    }

    private var buttonHelp: String {
        switch model.quickBar.phase {
        case .recording, .processing:
            return "停止当前口述"
        case .armed, .ready, .idle:
            return "关闭语音条"
        }
    }

    private func primaryAction() {
        if model.quickBar.isRecording || model.quickBar.phase == .processing {
            model.stopRecording()
        } else {
            model.dismissQuickBar()
        }
    }
}

private struct MiniWaveStrip: View {
    let level: Double
    let isSpeaking: Bool
    let phase: QuickBarPhase

    private let multipliers = [0.28, 0.56, 1.0, 0.82, 0.42]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(multipliers.enumerated()), id: \.offset) { index, multiplier in
                Capsule(style: .continuous)
                    .fill(AppTheme.brand400)
                    .frame(width: 4, height: barHeight(multiplier: multiplier, index: index))
                    .animation(.easeInOut(duration: 0.16), value: level)
                    .animation(.easeInOut(duration: 0.16), value: phase)
            }
        }
        .frame(width: 34, height: 24)
    }

    private func barHeight(multiplier: Double, index: Int) -> CGFloat {
        let minimumHeights = [8.0, 11.0, 18.0, 14.0, 9.0]
        let base = minimumHeights[index]

        guard phase == .recording || phase == .processing || phase == .armed else {
            return CGFloat(base)
        }

        let activeLevel = isSpeaking ? max(level, 0.16) : 0.12
        let dynamicHeight = base + (activeLevel * multiplier * 24)
        return CGFloat(min(24, dynamicHeight))
    }
}
