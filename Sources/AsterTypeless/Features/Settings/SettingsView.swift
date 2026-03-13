import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: TypelessAppModel

    var body: some View {
        Form {
            Section("触发") {
                TextField("主触发键", text: $model.settings.primaryTrigger)
                TextField("回退快捷键", text: $model.settings.fallbackShortcut)
            }

            Section("音频与语言") {
                TextField("麦克风", text: $model.settings.microphoneName)
                TextField("输出语言", text: $model.settings.outputLanguage)
            }

            Section("Provider") {
                TextField("当前方案", text: $model.settings.providerDisplayName)
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
                Toggle("开机启动", isOn: $model.settings.launchAtLogin)
                Button("刷新运行时配置") {
                    model.refreshRuntimeConfiguration()
                }
                .buttonStyle(.bordered)
            }

            Section("Provider 明细") {
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

                if !model.providerRuntime.lastError.isEmpty {
                    Text("错误: \(model.providerRuntime.lastError)")
                        .foregroundStyle(.red)
                }
            }

            Section("权限") {
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
            }

            Section("主链路体检") {
                HStack {
                    Text("当前结论")
                    Spacer()
                    Text(model.readinessReport.headline)
                        .multilineTextAlignment(.trailing)
                }

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
