import SwiftUI

@main
struct ToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Window("Tools", id: "main") {
            ModelsView()
                .environment(appDelegate.modelStore)
        }
        MenuBarExtra("Tools", systemImage: "wand.and.stars") {
            MenuBarView()
        }
        Settings {
            SettingsView()
        }
    }
}
