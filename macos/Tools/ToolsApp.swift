import SwiftUI

@main
struct ToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Tools", systemImage: "wand.and.stars") {
            MenuBarView()
        }
        Settings {
            SettingsView()
        }
    }
}
