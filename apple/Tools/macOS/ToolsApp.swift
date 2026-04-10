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
        .defaultSize(width: 1200, height: 700)
        MenuBarExtra("Tools", systemImage: "wand.and.stars") {
            MenuBarView()
        }
        Settings {
            SettingsView()
                .environment(appDelegate.textActionStore)
        }
    }
}
