import SwiftUI

@main
struct AsterTypelessApp: App {
    @StateObject private var model = TypelessAppModel()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some Scene {
        Window("AsterTypeless", id: "main") {
            HomeView(model: model)
                .background(MainWindowChromeConfigurator())
                .task {
                    model.bootstrap()
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(model: model, isPresented: $showOnboarding)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 760)

        MenuBarExtra("AsterTypeless", systemImage: "waveform.badge.mic") {
            MenuBarStatusView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
