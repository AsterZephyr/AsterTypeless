import SwiftUI

@main
struct TypelessMacApp: App {
    @StateObject private var model = TypelessAppModel()

    var body: some Scene {
        WindowGroup("Typeless") {
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
