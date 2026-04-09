import SwiftUI

@main
struct ToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var modelStore = ModelStore()
    @State private var aiService = AIService()

    var body: some Scene {
        Window("Tools", id: "main") {
            ModelsView()
                .environment(modelStore)
        }
        MenuBarExtra("Tools", systemImage: "wand.and.stars") {
            MenuBarView()
                .environment(modelStore)
                .environment(aiService)
        }
        Settings {
            SettingsView()
        }
    }
}
