import SwiftUI

@main
struct XiangqiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1060, height: 780)

        Settings {
            SettingsPane()
        }
    }
}
