import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let mainViewState = MainViewState()
    let actionsState = ActionsViewState()
    let myActionsState = MyActionsViewState()
    let templatesState = TemplatesViewState()
    let apiKeyStore = APIKeyStore()
    let modelsState = ModelsViewState()
    let downloadedState = DownloadedViewState()
    let exploreState = ExploreViewState()
    let permissionsService = PermissionsService()

    let llmService: LLMService
    let hfService: HFService
    let appleSpeechService: AppleSpeechService
    let modelService: ModelService
    let actionStore: ActionStore
    let dictationService: DictationService
    let quickActionsService: QuickActionsService

    override init() {
        let llmService = LLMService()
        let hfService = HFService()
        let appleSpeechService = AppleSpeechService()
        let modelService = ModelService(hfService: hfService, appleSpeechService: appleSpeechService)
        let actionStore = ActionStore()
        self.llmService = llmService
        self.hfService = hfService
        self.appleSpeechService = appleSpeechService
        self.modelService = modelService
        self.actionStore = actionStore
        self.dictationService = DictationService(stt: STTService(hfService: hfService, appleSpeechService: appleSpeechService))
        self.quickActionsService = QuickActionsService(
            llmService: llmService,
            hfService: hfService,
            modelService: modelService,
            actionStore: actionStore
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        permissionsService.startPolling()
        Task { await appleSpeechService.refresh() }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.dictationService.launch()
            self?.quickActionsService.launch()
        }
    }
}
