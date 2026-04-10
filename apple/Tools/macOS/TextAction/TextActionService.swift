import Foundation

enum TextAction: String, CaseIterable, Identifiable {
    case fixGrammar = "Fix Grammar"
    case summarize = "Summarize"
    case translateEnglish = "Translate to English"
    case makeShorter = "Make Shorter"
    case makeLonger = "Make Longer"

    var id: String { rawValue }

    var instruction: String {
        switch self {
        case .fixGrammar:
            "Fix the grammar and spelling. Preserve the original language and tone."
        case .summarize:
            "Summarize concisely."
        case .translateEnglish:
            "Translate to English."
        case .makeShorter:
            "Make shorter while preserving meaning."
        case .makeLonger:
            "Expand with more detail while preserving meaning and tone."
        }
    }

    func buildPrompt(for text: String) -> String {
        """
        \(instruction) Output ONLY the result, no explanations.

        <input>
        \(text)
        </input>
        """
    }
}

@Observable
@MainActor
final class TextActionService {

    enum Status: Equatable {
        case idle
        case copying
        case processing(original: String, result: String)
        case ready(original: String, result: String)
        case pasting
        case error(String)
    }

    private(set) var status: Status = .idle
    var editedResult = ""
    var selectedActionIndex = 0

    private let clipboard = ClipboardService()
    private let ai: AIService
    private let modelStore: ModelStore
    private var savedClipboard: String?
    private var currentTask: Task<Void, Never>?

    init(ai: AIService, modelStore: ModelStore) {
        self.ai = ai
        self.modelStore = modelStore
    }

    // MARK: - Phased API (for panel)

    func copySelectedText() async -> String? {
        guard ClipboardService.checkAccessibilityPermission() else {
            ClipboardService.requestAccessibilityPermission()
            status = .error("Accessibility permission required")
            return nil
        }

        savedClipboard = clipboard.save()
        status = .copying

        do {
            try await clipboard.simulateCopy()
            guard let text = clipboard.read(), !text.isEmpty else {
                clipboard.restore(savedClipboard)
                status = .error("No text selected")
                return nil
            }
            return text
        } catch {
            clipboard.restore(savedClipboard)
            status = .error(error.localizedDescription)
            return nil
        }
    }

    func processAction(_ action: TextAction, text: String) async {
        guard modelStore.isSelectedModelDownloaded else {
            status = .error("No model downloaded")
            return
        }

        status = .processing(original: text, result: "")

        let modelID = modelStore.selectedModelID
        let modelDir = modelStore.modelDirectory(for: modelID)

        do {
            try await ai.loadModel(id: modelID, directory: modelDir)

            var result = ""
            let stream = ai.generateStream(prompt: action.buildPrompt(for: text))
            for try await chunk in stream {
                result += chunk
                status = .processing(original: text, result: result)
            }
            editedResult = result
            status = .ready(original: text, result: result)
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func applyResult() async {
        guard case .ready = status else { return }

        status = .pasting
        clipboard.write(editedResult)

        do {
            try await clipboard.simulatePaste()
            try await Task.sleep(for: .milliseconds(200))
            clipboard.restore(savedClipboard)
            status = .idle
        } catch {
            clipboard.restore(savedClipboard)
            status = .error(error.localizedDescription)
        }
    }

    func dismiss() {
        currentTask?.cancel()
        currentTask = nil
        clipboard.restore(savedClipboard)
        status = .idle
    }

    // MARK: - One-shot API (for menu bar)

    func perform(_ action: TextAction) async {
        guard let text = await copySelectedText() else { return }
        await processAction(action, text: text)
        guard case .ready = status else { return }
        await applyResult()
    }
}
