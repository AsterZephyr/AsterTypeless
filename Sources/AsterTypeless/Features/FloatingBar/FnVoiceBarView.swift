import SwiftUI

struct FnVoiceBarView: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        HStack(spacing: 0) {
            WaveformPills(
                level: model.quickBar.smoothedLevel,
                isSpeaking: model.quickBar.isSpeaking,
                phase: model.quickBar.phase
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(
                    Color(red: 0.06, green: 0.07, blue: 0.12).opacity(0.92)
                )
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(accentGlow.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: accentGlow.opacity(0.2), radius: 20, y: 6)
        .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)
    }

    private var accentGlow: Color {
        switch model.quickBar.phase {
        case .recording:
            return model.quickBar.isSpeaking ? AppTheme.brand400 : AppTheme.brand600
        case .processing:
            return Color.orange
        default:
            return AppTheme.brand500
        }
    }
}

// MARK: - Waveform

private struct WaveformPills: View {
    let level: Double
    let isSpeaking: Bool
    let phase: QuickBarPhase

    // 11 bars, symmetric-ish pattern
    private let baseHeights: [Double] = [3, 5, 8, 12, 16, 20, 16, 12, 8, 5, 3]
    private let multipliers: [Double] = [0.2, 0.35, 0.55, 0.75, 0.9, 1.0, 0.9, 0.75, 0.55, 0.35, 0.2]

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0 ..< baseHeights.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor(index: index))
                    .frame(width: 3, height: barHeight(index: index))
                    .animation(.easeInOut(duration: 0.12), value: level)
                    .animation(.easeInOut(duration: 0.12), value: isSpeaking)
            }
        }
        .frame(height: 28)
    }

    private func barHeight(index: Int) -> CGFloat {
        let base = baseHeights[index]

        guard phase == .recording || phase == .armed else {
            // Processing: gentle pulse
            if phase == .processing {
                return CGFloat(base * 0.6 + 2)
            }
            return CGFloat(base * 0.3 + 2)
        }

        let activeLevel = isSpeaking ? max(level, 0.15) : 0.05
        let dynamic = base + activeLevel * multipliers[index] * 28
        return CGFloat(min(28, max(2, dynamic)))
    }

    private func barColor(index: Int) -> Color {
        let t = Double(index) / Double(baseHeights.count - 1)

        switch phase {
        case .recording:
            // Gradient from cyan to violet, brightness follows level
            let brightness = isSpeaking ? 0.7 + level * 0.3 : 0.4
            return gradientColor(t: t).opacity(brightness)
        case .processing:
            return Color.orange.opacity(0.5 + sin(Double(index) * 0.8) * 0.2)
        default:
            return AppTheme.brand500.opacity(0.3)
        }
    }

    private func gradientColor(t: Double) -> Color {
        // cyan -> blue -> violet
        if t < 0.5 {
            let local = t / 0.5
            return Color(
                red: 0.02 + local * 0.21,
                green: 0.71 - local * 0.20,
                blue: 0.83 + local * 0.13
            )
        } else {
            let local = (t - 0.5) / 0.5
            return Color(
                red: 0.23 + local * 0.32,
                green: 0.51 - local * 0.15,
                blue: 0.96 - local * 0.0
            )
        }
    }
}
