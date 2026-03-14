import SwiftUI

@main
struct AsterTypelessApp: App {
    @StateObject private var model = TypelessAppModel()

    var body: some Scene {
        Window("AsterTypeless", id: "main") {
            HomeView(model: model)
                .background(MainWindowChromeConfigurator())
                .task {
                    model.bootstrap()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 880)

        MenuBarExtra("AsterTypeless", systemImage: "waveform.badge.mic") {
            MenuBarStatusView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
