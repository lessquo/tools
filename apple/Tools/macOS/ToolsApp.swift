import SwiftUI

@main
struct ToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Window("Tools", id: "main") {
            MainView()
                .environment(appDelegate.modelStore)
                .environment(appDelegate.textActionStore)
        }
        MenuBarExtra("Tools", systemImage: "wand.and.stars") {
            MenuBarView()
        }
        Settings {
            SettingsView()
                .environment(appDelegate.textActionStore)
        }
    }
}
