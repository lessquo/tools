import AppKit

@Observable
@MainActor
final class FeaturesState {
    private static let dictationKey = "dictation.enabled"
    private static let quickActionsKey = "quickActions.enabled"

    var dictationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dictationEnabled, forKey: Self.dictationKey)
            onDictationChange?(dictationEnabled)
        }
    }

    var quickActionsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(quickActionsEnabled, forKey: Self.quickActionsKey)
            onQuickActionsChange?(quickActionsEnabled)
        }
    }

    @ObservationIgnored var onDictationChange: ((Bool) -> Void)?
    @ObservationIgnored var onQuickActionsChange: ((Bool) -> Void)?

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Self.dictationKey: false, Self.quickActionsKey: false])
        self.dictationEnabled = defaults.bool(forKey: Self.dictationKey)
        self.quickActionsEnabled = defaults.bool(forKey: Self.quickActionsKey)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let mainViewState = MainViewState()
    let llmService = LLMService()
    let actionStore = ActionStore()
    let actionsState = ActionsViewState()
    let myActionsState = MyActionsViewState()
    let templatesState = TemplatesViewState()
    let modelStore = ModelStore()
    let apiKeyStore = APIKeyStore()
    let modelsState = ModelsViewState()
    let libraryState = LibraryViewState()
    let exploreState = ExploreViewState()
    let featuresState = FeaturesState()
    let permissionsService = PermissionsService()
    private let shortcutMonitor = ShortcutMonitor()
    private var quickActions: QuickActionsPanel?
    private var dictationService: DictationService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        permissionsService.startPolling()
        let q = QuickActionsPanel(llmService: llmService, modelStore: modelStore, actionStore: actionStore)
        quickActions = q
        shortcutMonitor.onActivate = { [weak q] in
            q?.toggle()
        }
        dictationService = DictationService(modelStore: modelStore)

        featuresState.onQuickActionsChange = { [weak self] enabled in
            if enabled {
                self?.shortcutMonitor.start()
            } else {
                self?.shortcutMonitor.stop()
            }
        }
        featuresState.onDictationChange = { [weak self] enabled in
            if enabled {
                self?.dictationService?.start()
            } else {
                self?.dictationService?.stop()
            }
        }

        let startQuickActions = featuresState.quickActionsEnabled
        let startDictation = featuresState.dictationEnabled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if startQuickActions { self?.shortcutMonitor.start() }
            if startDictation { self?.dictationService?.start() }
        }
    }
}
