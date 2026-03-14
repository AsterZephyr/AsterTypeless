import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        Form {
            Section("输入方式") {
                TextField("主触发键", text: $model.settings.primaryTrigger)
                TextField("回退快捷键", text: $model.settings.fallbackShortcut)
                TextField("麦克风", text: $model.settings.microphoneName)
                TextField("输出语言", text: $model.settings.outputLanguage)
                HStack {
                    Text("回退绑定")
                    Spacer()
                    Text(model.fallbackShortcutRegistered ? "已绑定" : "未绑定")
                        .foregroundStyle(model.fallbackShortcutRegistered ? AppTheme.success : AppTheme.warning)
                }
                Button("重新绑定回退快捷键") {
                    model.refreshShortcutBindings()
                }
                .buttonStyle(.bordered)
            }

            Section("系统权限") {
                HStack {
                    Text("辅助功能")
                    Spacer()
                    Text(model.permissions.accessibility.label)
                }
                HStack {
                    Text("麦克风")
                    Spacer()
                    Text(model.permissions.microphone.label)
                }
                HStack {
                    Text("Fn 监听")
                    Spacer()
                    Text(model.permissions.inputMonitoring.label)
                }

                HStack {
                    Button("请求辅助功能权限") {
                        model.requestAccessibilityPermission()
                    }
                    .buttonStyle(.bordered)

                    Button("请求 Fn 权限") {
                        model.requestInputMonitoringPermission()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("应用行为") {
                HStack {
                    Text("文本处理方案")
                    Spacer()
                    Text(model.settings.providerDisplayName)
                }
                Toggle("开机启动", isOn: $model.settings.launchAtLogin)
            }

            Section("开发与诊断") {
                DisclosureGroup("展开调试信息") {
                    HStack {
                        Text("运行状态")
                        Spacer()
                        Text(model.providerRuntime.executionMode.title)
                    }

                    HStack {
                        Text("配置来源")
                        Spacer()
                        Text(model.providerRuntime.sourceDescription)
                    }

                    providerRow(title: "Deepgram", configured: model.providerRuntime.deepgramConfigured)
                    providerRow(title: "OpenAI", configured: model.providerRuntime.openAIConfigured)

                    if !model.providerRuntime.deepgramModel.isEmpty {
                        Text("Deepgram: \(model.providerRuntime.deepgramModel) · \(model.providerRuntime.deepgramLanguage)")
                    }

                    if !model.providerRuntime.openAIModel.isEmpty {
                        Text("OpenAI: \(model.providerRuntime.openAIModel)")
                    }

                    if !model.providerRuntime.openAITranscribeModel.isEmpty {
                        Text("OpenAI Transcribe: \(model.providerRuntime.openAITranscribeModel)")
                    }

                    Divider()

                    Text("这些内容只用于当前原型联调，不应该出现在首页。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    ForEach(model.readinessReport.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title)
                                Spacer()
                                Text(item.level.title)
                                    .foregroundStyle(color(for: item.level))
                            }
                            Text(item.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }

                    if !model.providerRuntime.lastError.isEmpty {
                        Text("错误: \(model.providerRuntime.lastError)")
                            .foregroundStyle(.red)
                    }

                    Button("刷新运行时配置") {
                        model.refreshRuntimeConfiguration()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520, height: 420)
    }

    @ViewBuilder
    private func providerRow(title: String, configured: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(configured ? "已配置" : "未配置")
                .foregroundStyle(configured ? AppTheme.success : AppTheme.warning)
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
