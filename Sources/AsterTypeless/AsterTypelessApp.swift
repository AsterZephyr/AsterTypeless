import SwiftUI

@main
struct AsterTypelessApp: App {
    @StateObject private var model = TypelessAppModel()

    var body: some Scene {
        WindowGroup("AsterTypeless") {
            HomeView(model: model)
                .task {
                    model.bootstrap()
                }
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(model: model)
        }
    }
}
