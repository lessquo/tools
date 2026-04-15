import Foundation

/// Coordinates the push-to-talk dictation flow:
/// fn down → show panel, load model, start capture
/// fn up   → stop capture, transcribe, paste, close panel
@MainActor
final class DictationController {

    private let modelStore: ModelStore
    private let audio = AudioCaptureService()
    private let stt = STTService()
    private let hotkey = HotkeyMonitor()
    private let clipboard = ClipboardService()
    private let panel: DictationPanel

    private var beginTask: Task<Void, Never>?

    init(modelStore: ModelStore) {
        self.modelStore = modelStore
        self.panel = DictationPanel(audio: audio, stt: stt)

        hotkey.onPress = { [weak self] in self?.beginDictation() }
        hotkey.onRelease = { [weak self] in self?.endDictation() }
    }

    func start() {
        hotkey.start()
    }

    func stop() {
        hotkey.stop()
        beginTask?.cancel()
        _ = audio.stop()
        panel.close()
    }

    // MARK: - Flow

    private func beginDictation() {
        guard beginTask == nil else { return }
        let id = modelStore.selectedModelID
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
