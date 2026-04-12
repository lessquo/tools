import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let modelStore = ModelStore()
    let modelsState = ModelsViewState()
    let libraryState = LibraryViewState()
    let exploreState = ExploreViewState()
    let aiService = AIService()
    let actionStore = ActionStore()
    private let shortcutManager = ShortcutManager()
    private var panel: ActionPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let p = ActionPanel(aiService: aiService, modelStore: modelStore, actionStore: actionStore)
        panel = p
        shortcutManager.onActivate = { [weak p] in
            p?.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.shortcutManager.start()
        }
    }
}
