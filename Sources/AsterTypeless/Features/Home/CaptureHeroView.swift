import SwiftUI

struct CaptureHeroView: View {
    @ObservedObject var model: TypelessAppModel
    let selectedSession: DictationSession?
    let isFloating: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.brand100.opacity(0.5))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)

                VStack(spacing: 30) {
                    captureButton
                        .offset(y: isFloating ? -10 : 0)

                    VStack(spacing: 12) {
                        Text("Ready to Capture")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255))

                        HStack(spacing: 8) {
                            Text("Press")
                                .foregroundStyle(Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255))
                            ShortcutKeyStack(shortcut: model.settings.fallbackShortcut)
                            Text("to start speaking")
                                .foregroundStyle(Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255))
                        }
                        .font(.system(size: 14, weight: .medium))
                    }

                    statusBadge
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Spacer()
        }
        .padding(.bottom, 32)
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.brand600)
                Text("Acoustica")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255))
            }

            Spacer()

            HStack(spacing: 12) {
                buttonIcon("moon.stars")

                SettingsLink {
                    buttonIcon("gearshape")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var captureButton: some View {
        Button {
            if model.quickBar.isRecording {
                model.stopRecording(for: model.quickBar.captureMode)
            } else {
                model.presentQuickBar(trigger: "手动", captureMode: .manual)
                model.startRecording(captureMode: .manual)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .shadow(color: AppTheme.brand600.opacity(0.15), radius: 20, y: 10)
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.brand50, .white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 156, height: 156)
                    .opacity(0.86)

                Circle()
                    .stroke(AppTheme.brand600.opacity(0.08), lineWidth: 1)
                    .frame(width: 160, height: 160)

                if model.quickBar.isRecording {
                    Circle()
                        .stroke(AppTheme.brand500.opacity(0.34), lineWidth: 2)
                        .frame(width: 168, height: 168)
                    Circle()
                        .stroke(AppTheme.brand500.opacity(0.18), lineWidth: 2)
                        .frame(width: 180, height: 180)
                }

                AcousticGlyph()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.brand600, AppTheme.brand900],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(model.quickBar.isRecording ? 1.03 : 1)
        .shadow(color: model.quickBar.isRecording ? AppTheme.brand600.opacity(0.18) : .clear, radius: 18)
        .animation(.spring(duration: 0.4, bounce: 0.28), value: model.quickBar.isRecording)
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
            Text(statusBadgeText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.44))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255).opacity(0.75), lineWidth: 1)
        }
    }

    private var statusBadgeText: String {
        if model.quickBar.isRecording {
            return "Capturing partial transcript live"
        }

        if let selectedSession {
            return "Last note from \(selectedSession.sourceAppName) is ready to reuse"
        }

        return "Auto-saves immediately on close"
    }

    @ViewBuilder
    private func buttonIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Color(red: 100 / 255, green: 116 / 255, blue: 139 / 255))
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.32))
            )
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.48), lineWidth: 1)
            }
    }
}

struct RecordingStatusHUD: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        HStack(spacing: 14) {
            MiniWaveLevels(level: model.quickBar.smoothedLevel, isActive: model.quickBar.isRecording)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.quickBar.isRecording ? "Recording" : "Standby")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255))
                    .textCase(.uppercase)
                    .tracking(1.1)

                Text(recordingClock)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Button {
                if model.quickBar.isRecording {
                    model.stopRecording(for: model.quickBar.captureMode)
                } else {
                    model.presentQuickBar(trigger: "手动", captureMode: .manual)
                    model.startRecording(captureMode: .manual)
                }
            } label: {
                Image(systemName: model.quickBar.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(model.quickBar.isRecording ? Color.red.opacity(0.9) : Color.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(model.quickBar.isRecording ? 0.14 : 0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.76))
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(AppTheme.brand500.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: AppTheme.brand600.opacity(0.24), radius: 24, y: 10)
    }

    private var recordingClock: String {
        let duration = model.quickBar.capturedDuration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration * 10).rounded()) % 10
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
}

private struct MiniWaveLevels: View {
    let level: Double
    let isActive: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0 ..< 5, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(isActive ? AppTheme.brand400 : Color.white.opacity(0.26))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.18), value: level)
            }
        }
        .frame(width: 32, height: 26)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base = [8.0, 12.0, 18.0, 14.0, 10.0][index]
        let gain = isActive ? max(level, 0.14) : 0
        return CGFloat(base + gain * Double((index + 2) * 7))
    }
}

private struct ShortcutKeyStack: View {
    let shortcut: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tokens, id: \.self) { token in
                Text(token)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 51 / 255, green: 65 / 255, blue: 85 / 255))
                    .padding(.horizontal, token.count == 1 ? 8 : 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
            }
        }
    }

    private var tokens: [String] {
        let cleaned = shortcut
            .replacingOccurrences(of: "CommandOrControl", with: "⌘")
            .replacingOccurrences(of: "Control", with: "⌃")
            .replacingOccurrences(of: "Option", with: "⌥")
            .replacingOccurrences(of: "Shift", with: "⇧")
            .replacingOccurrences(of: "+", with: " + ")

        return cleaned
            .split(separator: " ")
            .filter { $0 != "+" }
            .map(String.init)
    }
}

private struct AcousticGlyph: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let barWidth = size * 0.075
            let heights = [0.20, 0.44, 0.68, 0.82, 0.68, 0.44, 0.20]

            ZStack {
                Circle()
                    .stroke(AppTheme.brand600.opacity(0.12), style: StrokeStyle(lineWidth: 1.3, dash: [4, 6]))
                    .frame(width: size * 0.95, height: size * 0.95)

                Circle()
                    .stroke(AppTheme.brand600.opacity(0.18), style: StrokeStyle(lineWidth: 1.3, dash: [2, 4]))
                    .frame(width: size * 0.78, height: size * 0.78)

                HStack(alignment: .center, spacing: barWidth * 0.65) {
                    ForEach(Array(heights.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.brand600, AppTheme.brand900],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: barWidth, height: size * value)
                    }
                }
            }
        }
    }
}
