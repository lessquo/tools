import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let modelStore = ModelStore()
    let aiService = AIService()
    let textActionStore = TextActionStore()
    private let shortcutManager = ShortcutManager()
    private var panel: TextActionPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let p = TextActionPanel(aiService: aiService, modelStore: modelStore, textActionStore: textActionStore)
        panel = p
        shortcutManager.onActivate = { [weak p] in
            p?.toggle()
        }
        shortcutManager.start()
    }
}
