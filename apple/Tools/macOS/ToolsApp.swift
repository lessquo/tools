import SwiftUI

@main
struct ToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var modelStore = ModelStore()
    @State private var aiService = AIService()
    @State private var shortcutManager = ShortcutManager()
    @State private var panel: TextActionPanel?

    var body: some Scene {
        Window("Tools", id: "main") {
            ModelsView()
                .environment(modelStore)
        }
        MenuBarExtra("Tools", systemImage: "wand.and.stars") {
            MenuBarView()
                .task { setupPanel() }
        }
        Settings {
            SettingsView()
        }
    }

    private func setupPanel() {
        guard panel == nil else { return }
        let p = TextActionPanel(aiService: aiService, modelStore: modelStore)
        panel = p
        shortcutManager.onActivate = { [weak p] in
            p?.toggle()
        }
        shortcutManager.start()
    }
}
