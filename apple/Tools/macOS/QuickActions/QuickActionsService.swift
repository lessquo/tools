import Foundation

@Observable
@MainActor
final class QuickActionsService {
    private static let enabledKey = "quickActions.enabled"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            applyEnabled()
        }
    }

    private let shortcut = ShortcutMonitor()
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
        shortcut.onActivate = { [weak self] in self?.panel.toggle() }
    }

    /// Apply the persisted enabled state. Call once at app launch.
    func launch() {
        applyEnabled()
    }

    private func applyEnabled() {
        if isEnabled { shortcut.start() } else { shortcut.stop() }
    }
}
