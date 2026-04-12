import SwiftUI

@main
struct ToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Window("Tools", id: "main") {
            MainView()
                .environment(appDelegate.modelStore)
                .environment(appDelegate.modelsState)
                .environment(appDelegate.libraryState)
                .environment(appDelegate.exploreState)
                .environment(appDelegate.actionStore)
        }
        .defaultSize(width: 1200, height: 700)
        Settings {
            SettingsView()
                .environment(appDelegate.actionStore)
        }
    }
}
