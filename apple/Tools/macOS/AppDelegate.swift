import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let mainViewState = MainViewState()
    let actionsState = ActionsViewState()
    let myActionsState = MyActionsViewState()
    let templatesState = TemplatesViewState()
    let apiKeyStore = APIKeyStore()
    let modelsState = ModelsViewState()
    let libraryState = LibraryViewState()
    let exploreState = ExploreViewState()
    let permissionsService = PermissionsService()

    let llmService: LLMService
    let modelStore: ModelStore
    let actionStore: ActionStore
    let dictationService: DictationService
    let quickActionsService: QuickActionsService

    override init() {
        let llmService = LLMService()
        let modelStore = ModelStore()
        let actionStore = ActionStore()
        self.llmService = llmService
        self.modelStore = modelStore
        self.actionStore = actionStore
        self.dictationService = DictationService(modelStore: modelStore)
        self.quickActionsService = QuickActionsService(
            llmService: llmService,
            modelStore: modelStore,
            actionStore: actionStore
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        permissionsService.startPolling()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.dictationService.launch()
            self?.quickActionsService.launch()
        }
    }
}
