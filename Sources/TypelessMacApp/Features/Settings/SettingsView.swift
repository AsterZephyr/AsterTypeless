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
                Toggle("开机启动", isOn: $model.settings.launchAtLogin)
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
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520, height: 420)
    }
}

