import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let navigationState = NavigationState()
    let modelStore = ModelStore()
    let modelsState = ModelsViewState()
    let libraryState = LibraryViewState()
    let exploreState = ExploreViewState()
    let aiService = AIService()
    let actionStore = ActionStore()
    let actionsState = ActionsViewState()
    let myActionsState = MyActionsViewState()
    let templatesState = TemplatesViewState()
    private let shortcutManager = ShortcutManager()
    private var panel: ActionPanel?
    private var dictationController: DictationController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let p = ActionPanel(aiService: aiService, modelStore: modelStore, actionStore: actionStore)
        panel = p
        shortcutManager.onActivate = { [weak p] in
            p?.toggle()
        }
        dictationController = DictationController(modelStore: modelStore)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.shortcutManager.start()
            self?.dictationController?.start()
        }
    }
}
