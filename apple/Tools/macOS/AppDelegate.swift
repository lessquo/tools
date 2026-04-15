import AppKit

@Observable
@MainActor
final class FeaturesState {
    private static let dictationKey = "dictation.enabled"
    private static let actionPanelKey = "actionPanel.enabled"

    var dictationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dictationEnabled, forKey: Self.dictationKey)
            onDictationChange?(dictationEnabled)
        }
    }

    var actionPanelEnabled: Bool {
        didSet {
            UserDefaults.standard.set(actionPanelEnabled, forKey: Self.actionPanelKey)
            onActionPanelChange?(actionPanelEnabled)
        }
    }

    @ObservationIgnored var onDictationChange: ((Bool) -> Void)?
    @ObservationIgnored var onActionPanelChange: ((Bool) -> Void)?

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Self.dictationKey: true, Self.actionPanelKey: true])
        self.dictationEnabled = defaults.bool(forKey: Self.dictationKey)
        self.actionPanelEnabled = defaults.bool(forKey: Self.actionPanelKey)
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
    let modelsState = ModelsViewState()
    let libraryState = LibraryViewState()
    let exploreState = ExploreViewState()
    let featuresState = FeaturesState()
    private let shortcutMonitor = ShortcutMonitor()
    private var panel: ActionPanel?
    private var dictationController: DictationController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let p = ActionPanel(llmService: llmService, modelStore: modelStore, actionStore: actionStore)
        panel = p
        shortcutMonitor.onActivate = { [weak p] in
            p?.toggle()
        }
        dictationController = DictationController(modelStore: modelStore)

        featuresState.onActionPanelChange = { [weak self] enabled in
            if enabled {
                self?.shortcutMonitor.start()
            } else {
                self?.shortcutMonitor.stop()
            }
        }
        featuresState.onDictationChange = { [weak self] enabled in
            if enabled {
                self?.dictationController?.start()
            } else {
                self?.dictationController?.stop()
            }
        }

        let startActionPanel = featuresState.actionPanelEnabled
        let startDictation = featuresState.dictationEnabled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if startActionPanel { self?.shortcutMonitor.start() }
            if startDictation { self?.dictationController?.start() }
        }
    }
}
