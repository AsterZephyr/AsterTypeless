import AppKit
import SwiftUI

struct MenuBarStatusView: View {
    @ObservedObject var model: TypelessAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 8) {
                menuRow(title: "主触发键", value: model.settings.primaryTrigger)
                menuRow(title: "回退快捷键", value: model.settings.fallbackShortcut)
                menuRow(title: "Provider", value: model.providerRuntime.executionMode.title)
            }

            HStack(spacing: 8) {
                StatusPill(title: "辅助功能 \(model.permissions.accessibility.label)", tint: tint(for: model.permissions.accessibility))
                StatusPill(title: "Fn \(model.permissions.inputMonitoring.label)", tint: tint(for: model.permissions.inputMonitoring))
            }

            Divider()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                model.presentQuickBar(trigger: "菜单栏")
            } label: {
                Label("开始快速口述", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            } label: {
                Label("打开主窗口", systemImage: "rectangle.on.rectangle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)

            SettingsLink {
                Label("打开设置", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AsterTypeless")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
            Text(model.readinessReport.headline)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.muted)
        }
    }

    private func menuRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
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
