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
        .frame(width: 336)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("菜单栏")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text("AsterTypeless")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text(model.readinessReport.headline)
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var quickActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            menuSectionHeader(
                title: "快速开始",
                detail: "在这里直接开始口述，或者回到主窗口继续查看记录。"
            )

            Button {
                NSApp.activate(ignoringOtherApps: true)
                model.presentQuickBar(trigger: "菜单栏")
            } label: {
                Label("开始快速口述", systemImage: "mic.fill")
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
                    Label("主窗口", systemImage: "rectangle.on.rectangle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)

                SettingsLink {
                    Label("设置", systemImage: "gearshape")
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
                title: "当前状态",
                detail: "保留真正会影响体验的几项状态，不再堆叠开发信息。"
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
                Text("如果 Fn 还没授权，应用会先回退到组合快捷键。")
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
