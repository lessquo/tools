import Foundation

/// Coordinates the push-to-talk dictation flow:
/// fn down → show panel, load model, start capture
/// fn up   → stop capture, transcribe, paste, close panel
@Observable
@MainActor
final class DictationService {
    private static let enabledKey = "dictation.enabled"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            applyEnabled()
        }
    }

    private let modelStore: ModelStore
    private let audio = AudioCaptureService()
    private let stt = STTService()
    private let shortcut = HoldShortcutMonitor()
    private let clipboard = ClipboardService()
    private let panel: DictationPanel

    private var beginTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?

    init(modelStore: ModelStore) {
        self.modelStore = modelStore
        self.panel = DictationPanel(audio: audio, stt: stt)

        let defaults = UserDefaults.standard
        defaults.register(defaults: [Self.enabledKey: false])
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)

        shortcut.onPress = { [weak self] in self?.beginDictation() }
        shortcut.onRelease = { [weak self] in self?.endDictation() }
    }

    /// Apply the persisted enabled state. Call once at app launch.
    func launch() {
        applyEnabled()
    }

    private func applyEnabled() {
        if isEnabled { start() } else { stop() }
    }

    private func start() {
        shortcut.start()
        preloadModel()
    }

    private func stop() {
        shortcut.stop()
        beginTask?.cancel()
        preloadTask?.cancel()
        preloadTask = nil
        _ = audio.stop()
        panel.close()
    }

    private func preloadModel() {
        let id = withObservationTracking {
            modelStore.modelID(for: .dictation)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isEnabled else { return }
                self.preloadModel()
            }
        }

        preloadTask?.cancel()
        guard !id.isEmpty else { return }
        let directory = modelStore.modelDirectory(for: id)
        preloadTask = Task { [stt] in
            try? await stt.loadModel(id: id, directory: directory)
        }
    }

    // MARK: - Flow

    private func beginDictation() {
        guard beginTask == nil else { return }
        let id = modelStore.modelID(for: .dictation)
        guard !id.isEmpty else { return }
        let directory = modelStore.modelDirectory(for: id)

        panel.show()

        beginTask = Task { [stt, audio, panel] in
            do {
                try await stt.loadModel(id: id, directory: directory)
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

            let text = (try? await stt.transcribe(pcm: pcm)) ?? ""
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
