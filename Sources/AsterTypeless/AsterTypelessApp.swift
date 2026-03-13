import SwiftUI

@main
struct AsterTypelessApp: App {
    @StateObject private var model = TypelessAppModel()

    var body: some Scene {
        Window("AsterTypeless", id: "main") {
            HomeView(model: model)
                .task {
                    model.bootstrap()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1040, height: 760)

        MenuBarExtra("AsterTypeless", systemImage: "waveform.badge.mic") {
            MenuBarStatusView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
