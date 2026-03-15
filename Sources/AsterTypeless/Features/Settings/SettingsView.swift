import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(alignment: .leading, spacing: 22) {
                    inputSection

                    Divider()

                    permissionsSection

                    Divider()

                    behaviorSection

                    Divider()

                    appearanceSection

                    Divider()

                    diagnosticsSection
                }
                .cardSurface()
            }
            .padding(24)
            .frame(width: 560, alignment: .leading)
        }
        .background(AppTheme.backgroundTop)
        .frame(width: 560, height: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("设置")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            Text("把权限、触发方式和应用行为收进一个原生面板。")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text("这里保留需要配置的内容；联调用的状态只放在最下面的诊断区。")
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(
                title: "输入方式",
                detail: "主触发键、回退快捷键和输出语言都收在这里。"
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SettingsTextField(title: "主触发键", text: $model.settings.primaryTrigger)
                SettingsTextField(title: "回退快捷键", text: $model.settings.fallbackShortcut)
                SettingsTextField(title: "麦克风", text: $model.settings.microphoneName)
                SettingsTextField(title: "输出语言", text: $model.settings.outputLanguage)
            }

            HStack(spacing: 10) {
                SettingsValueTile(
                    title: "回退绑定",
                    value: model.fallbackShortcutRegistered ? "已绑定" : "未绑定",
                    tint: model.fallbackShortcutRegistered ? AppTheme.success : AppTheme.warning
                )

                Spacer()

                Button("重新绑定回退快捷键") {
                    model.refreshShortcutBindings()
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
            }
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(
                title: "系统权限",
                detail: "只要权限没开全，跨 App 写回和 Fn 监听就不会稳定。"
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                SettingsValueTile(title: "辅助功能", value: model.permissions.accessibility.label, tint: color(for: model.permissions.accessibility))
                SettingsValueTile(title: "麦克风", value: model.permissions.microphone.label, tint: color(for: model.permissions.microphone))
                SettingsValueTile(title: "Fn 监听", value: model.permissions.inputMonitoring.label, tint: color(for: model.permissions.inputMonitoring))
            }

            HStack(spacing: 10) {
                Button("请求辅助功能权限") {
                    model.requestAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
                .tint(AppTheme.accent)

                Button("请求 Fn 权限") {
                    model.requestInputMonitoringPermission()
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
            }
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(
                title: "应用行为",
                detail: "这里放长期配置，不再混进临时调试状态。"
            )

            HStack(spacing: 10) {
                SettingsValueTile(title: "文本处理方案", value: model.settings.providerDisplayName, tint: AppTheme.ink)

                SettingsValueTile(
                    title: "Provider 状态",
                    value: model.providerRuntime.canUseOpenAI ? "已配置" : "未配置",
                    tint: model.providerRuntime.canUseOpenAI ? AppTheme.success : AppTheme.warning
                )
            }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(
                title: "外观",
                detail: "在浅色、深色和跟随系统之间切换。"
            )

            Picker("外观模式", selection: Binding(
                get: { model.appearanceMode },
                set: { newValue in
                    model.appearanceMode = newValue
                    AppTheme.apply(appearance: newValue)
                }
            )) {
                ForEach(AppTheme.AppearanceMode.allCases, id: \.self) { mode in
                    Label(mode.title, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionHeader(
                title: "开发与诊断",
                detail: "这些内容只留给当前原型联调，不应该回到首页。"
            )

            DisclosureGroup("展开调试信息") {
                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                        SettingsValueTile(title: "运行状态", value: model.providerRuntime.executionMode.title, tint: AppTheme.ink)
                        SettingsValueTile(title: "配置来源", value: model.providerRuntime.sourceDescription, tint: AppTheme.ink)
                        SettingsValueTile(title: "Deepgram", value: model.providerRuntime.deepgramConfigured ? "已配置" : "未配置", tint: model.providerRuntime.deepgramConfigured ? AppTheme.success : AppTheme.warning)
                        SettingsValueTile(title: "OpenAI", value: model.providerRuntime.openAIConfigured ? "已配置" : "未配置", tint: model.providerRuntime.openAIConfigured ? AppTheme.success : AppTheme.warning)
                    }

                    if !model.providerRuntime.deepgramModel.isEmpty {
                        SettingsDiagnosticLine(text: "Deepgram: \(model.providerRuntime.deepgramModel) · \(model.providerRuntime.deepgramLanguage)")
                    }

                    if !model.providerRuntime.openAIModel.isEmpty {
                        SettingsDiagnosticLine(text: "OpenAI: \(model.providerRuntime.openAIModel)")
                    }

                    if !model.providerRuntime.openAITranscribeModel.isEmpty {
                        SettingsDiagnosticLine(text: "OpenAI Transcribe: \(model.providerRuntime.openAITranscribeModel)")
                    }

                    ForEach(model.readinessReport.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                Text(item.level.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(color(for: item.level))
                            }

                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        .insetSurface()
                    }

                    if !model.providerRuntime.lastError.isEmpty {
                        SettingsDiagnosticLine(text: "错误: \(model.providerRuntime.lastError)", tint: .red)
                    }

                    Button("刷新运行时配置") {
                        model.refreshRuntimeConfiguration()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                    .controlSize(.large)
                }
                .padding(.top, 12)
            }
        }
    }

    private func color(for state: PermissionState) -> Color {
        switch state {
        case .granted:
            return AppTheme.success
        case .required:
            return AppTheme.warning
        case .unavailable:
            return AppTheme.muted
        }
    }

    private func color(for level: ReadinessLevel) -> Color {
        switch level {
        case .ready:
            return AppTheme.success
        case .attention:
            return AppTheme.warning
        case .blocked:
            return AppTheme.accent
        }
    }
}

private struct SettingsSectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text(detail)
                .font(.callout)
                .foregroundStyle(AppTheme.muted)
        }
    }
}

private struct SettingsTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
        }
        .insetSurface()
    }
}

private struct SettingsValueTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .insetSurface()
    }
}

private struct SettingsDiagnosticLine: View {
    let text: String
    var tint: Color = AppTheme.muted

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .insetSurface()
    }
}
