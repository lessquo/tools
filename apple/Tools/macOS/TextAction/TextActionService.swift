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
        case processing
        case pasting
        case error(String)
    }

    private(set) var status: Status = .idle

    private let clipboard = ClipboardService()
    private let ai: AIService
    private let modelStore: ModelStore

    init(ai: AIService, modelStore: ModelStore) {
        self.ai = ai
        self.modelStore = modelStore
    }

    func perform(_ action: TextAction) async {
        guard ClipboardService.checkAccessibilityPermission() else {
            ClipboardService.requestAccessibilityPermission()
            status = .error("Accessibility permission required")
            return
        }

        guard modelStore.isSelectedModelDownloaded else {
            status = .error("No model downloaded")
            return
        }

        let originalClipboard = clipboard.save()

        do {
            // Copy selected text
            status = .copying
            try await clipboard.simulateCopy()

            guard let selectedText = clipboard.read(), !selectedText.isEmpty else {
                clipboard.restore(originalClipboard)
                status = .error("No text selected")
                return
            }

            // Process with AI
            status = .processing
            let modelID = modelStore.selectedModelID
            let modelDir = modelStore.modelDirectory(for: modelID)

            try await ai.loadModel(id: modelID, directory: modelDir)
            let result = try await ai.generate(
                prompt: action.buildPrompt(for: selectedText)
            )

            // Replace selection
            status = .pasting
            clipboard.write(result)
            try await clipboard.simulatePaste()

            // Restore original clipboard
            try await Task.sleep(for: .milliseconds(200))
            clipboard.restore(originalClipboard)

            status = .idle
        } catch {
            clipboard.restore(originalClipboard)
            status = .error(error.localizedDescription)
        }
    }
}
