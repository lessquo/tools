import Foundation

@Observable
@MainActor
final class QuickActionsService {
    private static let enabledKey = "quickActions.enabled"
    private static let shortcutKey = "quickActions.shortcut"
    private static let modelIDKey = "quickActions.modelID"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            applyEnabled()
        }
    }

    var shortcut: Shortcut {
        didSet {
            shortcut.save(forKey: Self.shortcutKey)
            applyShortcut()
        }
    }

    var modelID: String {
        didSet { UserDefaults.standard.set(modelID, forKey: Self.modelIDKey) }
    }

    private let monitor = ShortcutMonitor()
    private let panel: QuickActionsPanel

    init(llmService: LLMService, modelStore: ModelStore, actionStore: ActionStore) {
        self.panel = QuickActionsPanel(
            llmService: llmService,
            modelStore: modelStore,
            actionStore: actionStore
        )
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Self.enabledKey: false])
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        self.shortcut = Shortcut.load(forKey: Self.shortcutKey, default: .quickActionsDefault)
        self.modelID = defaults.string(forKey: Self.modelIDKey) ?? ""
        panel.modelIDProvider = { [weak self] in self?.modelID ?? "" }
        monitor.onActivate = { [weak self] in self?.panel.toggle() }
    }

    func launch() {
        applyEnabled()
    }

    private func applyEnabled() {
        if isEnabled { monitor.start(shortcut) } else { monitor.stop() }
    }

    private func applyShortcut() {
        guard isEnabled else { return }
        monitor.start(shortcut)
    }
}
