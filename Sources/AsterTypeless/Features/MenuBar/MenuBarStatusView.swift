import AppKit
import SwiftUI

struct MenuBarStatusView: View {
    @ObservedObject var model: TypelessAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            quickActionSection
            statusSection
        }
        .padding(18)
        .frame(width: 356)
        .background(AppTheme.backgroundTop)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.brand600)

            VStack(alignment: .leading, spacing: 3) {
                Text("Acoustica")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text("Quick access from the menu bar")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }

    private var quickActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            menuSectionHeader(
                title: "Quick start",
                detail: "Open the floating bar or jump back into the main window."
            )

            Button {
                NSApp.activate(ignoringOtherApps: true)
                model.presentQuickBar(trigger: "菜单栏", captureMode: .manual)
                model.startRecording(captureMode: .manual)
            } label: {
                Label("Start dictation", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)
            .controlSize(.large)
            .tint(AppTheme.accent)

            HStack(spacing: 10) {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                } label: {
                    Label("Open app", systemImage: "rectangle.on.rectangle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)

                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
            }
        }
        .cardSurface()
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            menuSectionHeader(
                title: "Current status",
                detail: "Only the pieces that affect dictation quality and system access."
            )

            HStack(spacing: 10) {
                compactTile(title: "触发", value: model.settings.primaryTrigger)
                compactTile(title: "回退", value: model.settings.fallbackShortcut)
                compactTile(title: "处理", value: model.settings.providerDisplayName)
            }

            VStack(alignment: .leading, spacing: 10) {
                menuRow(title: "主触发键", value: model.settings.primaryTrigger)
                menuRow(title: "回退快捷键", value: model.settings.fallbackShortcut)
                menuRow(title: "文本处理", value: model.providerRuntime.executionMode.title)
            }
            .insetSurface()

            HStack(spacing: 8) {
                StatusPill(title: "辅助功能 \(model.permissions.accessibility.label)", tint: tint(for: model.permissions.accessibility))
                StatusPill(title: "Fn \(model.permissions.inputMonitoring.label)", tint: tint(for: model.permissions.inputMonitoring))
            }

            if model.permissions.inputMonitoring != .granted {
                Text("If Fn is still blocked by the system, the app falls back to the shortcut route.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .cardSurface()
    }

    private func menuSectionHeader(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            Text(detail)
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private func compactTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insetSurface()
    }

    private func menuRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private func tint(for state: PermissionState) -> Color {
        switch state {
        case .granted:
            return AppTheme.success
        case .required:
            return AppTheme.warning
        case .unavailable:
            return AppTheme.muted
        }
    }
}
