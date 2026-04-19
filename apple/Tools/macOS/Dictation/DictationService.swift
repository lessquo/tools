import Foundation

@Observable
@MainActor
final class DictationService {
    private static let enabledKey = "dictation.enabled"
    private static let shortcutKey = "dictation.shortcut"
    private static let modelIDKey = "dictation.modelID"

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

    private let modelStore: ModelStore
    private let audio = AudioCaptureService()
    private let stt: STTService
    private let monitor = ShortcutMonitor()
    private let clipboard = ClipboardService()
    private let panel: DictationPanel

    private var beginTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?

    init(modelStore: ModelStore) {
        self.modelStore = modelStore
        let stt = STTService(modelStore: modelStore)
        self.stt = stt
        self.panel = DictationPanel(audio: audio, stt: stt)

        let defaults = UserDefaults.standard
        defaults.register(defaults: [Self.enabledKey: false])
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        self.shortcut = Shortcut.load(forKey: Self.shortcutKey, default: .dictationDefault)
        let savedModelID = defaults.string(forKey: Self.modelIDKey) ?? ""
        self.modelID = savedModelID.isEmpty ? STTService.appleSpeechID : savedModelID

        monitor.onPress = { [weak self] in self?.beginDictation() }
        monitor.onRelease = { [weak self] in self?.endDictation() }
    }

    func launch() {
        applyEnabled()
    }

    private func applyEnabled() {
        if isEnabled { start() } else { stop() }
    }

    private func applyShortcut() {
        guard isEnabled else { return }
        monitor.start(shortcut)
    }

    private func start() {
        monitor.start(shortcut)
        preloadModel()
    }

    private func stop() {
        monitor.stop()
        beginTask?.cancel()
        preloadTask?.cancel()
        preloadTask = nil
        _ = audio.stop()
        panel.close()
    }

    private func preloadModel() {
        let id = withObservationTracking {
            modelID
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isEnabled else { return }
                self.preloadModel()
            }
        }

        preloadTask?.cancel()
        guard !id.isEmpty else { return }
        preloadTask = Task { [stt, modelStore] in
            try? await stt.loadModel(id: id)
            if id == STTService.appleSpeechID {
                await modelStore.refreshAppleSpeechStatus()
            }
        }
    }

    // MARK: - Flow

    private func beginDictation() {
        guard beginTask == nil else { return }
        let id = modelID
        guard !id.isEmpty else { return }

        panel.show()

        beginTask = Task { [stt, audio, panel] in
            do {
                try await stt.loadModel(id: id)
                try Task.checkCancellation()
                try await audio.start()
            } catch {
                panel.close()
            }
        }
    }

    private func endDictation() {
        let pending = beginTask
        beginTask = nil
        pending?.cancel()

        Task { [audio, stt, panel, clipboard] in
            // Wait for the begin task to finish so audio.start() and audio.stop()
            // don't race (we want to avoid leaving the engine running).
            _ = await pending?.value

            let pcm = audio.stop()

            guard !pcm.isEmpty else {
                panel.close()
                return
            }

            let text = (try? await stt.transcribe(pcm: pcm, sampleRate: audio.sampleRate)) ?? ""
            panel.close()

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            await Self.paste(trimmed, clipboard: clipboard)
        }
    }

    // MARK: - Paste

    private static func paste(_ text: String, clipboard: ClipboardService) async {
        let previous = clipboard.save()
        clipboard.write(text)
        try? await clipboard.simulatePaste()
        try? await Task.sleep(for: .milliseconds(150))
        clipboard.restore(previous)
    }
}
