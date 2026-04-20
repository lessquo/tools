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
    let hfService: HFService
    let actionStore: ActionStore
    let dictationService: DictationService
    let quickActionsService: QuickActionsService

    override init() {
        let llmService = LLMService()
        let hfService = HFService()
        let actionStore = ActionStore()
        self.llmService = llmService
        self.hfService = hfService
        self.actionStore = actionStore
        self.dictationService = DictationService(hfService: hfService)
        self.quickActionsService = QuickActionsService(
            llmService: llmService,
            hfService: hfService,
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
