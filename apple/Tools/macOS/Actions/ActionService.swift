import Foundation
import JavaScriptCore

struct Action: Codable, Identifiable, Equatable {

    enum ActionType: String, Codable, CaseIterable {
        case llm
        case script
    }

    var id: UUID
    var name: String
    var type: ActionType
    var prompt: String
    var script: String

    init(id: UUID, name: String, type: ActionType = .llm, prompt: String = "", script: String = "") {
        self.id = id
        self.name = name
        self.type = type
        self.prompt = prompt
        self.script = script
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(ActionType.self, forKey: .type) ?? .llm
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        script = try container.decodeIfPresent(String.self, forKey: .script) ?? ""
    }


    static let defaults: [Action] = [
        Action(id: UUID(), name: "Fix Grammar", prompt: "Fix the grammar and spelling. Preserve the original language and tone. Output ONLY the result.\n\n{{input}}"),
        Action(id: UUID(), name: "Summarize", prompt: "Summarize concisely. Output ONLY the result.\n\n{{input}}"),
        Action(id: UUID(), name: "Translate to English", prompt: "Translate to English. Output ONLY the result.\n\n{{input}}"),
        Action(id: UUID(), name: "Sort Lines", type: .script, script: "output = input.split('\\n').sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' })).join('\\n')"),
        Action(id: UUID(), name: "Count Words", type: .script, script: "output = input.trim().split(/\\s+/).filter(w => w.length > 0).length + ' words'"),
    ]

    static let templates: [Action] = [
        Action(id: UUID(), name: "Fix Grammar", prompt: "Fix the grammar and spelling. Preserve the original language and tone. Output ONLY the result.\n\n{{input}}"),
        Action(id: UUID(), name: "Summarize", prompt: "Summarize concisely. Output ONLY the result.\n\n{{input}}"),
        Action(id: UUID(), name: "Translate to English", prompt: "Translate to English. Output ONLY the result.\n\n{{input}}"),
        Action(id: UUID(), name: "Sort Lines", type: .script, script: "output = input.split('\\n').sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' })).join('\\n')"),
        Action(id: UUID(), name: "Count Words", type: .script, script: "output = input.trim().split(/\\s+/).filter(w => w.length > 0).length + ' words'"),
        Action(id: UUID(), name: "Title Case", type: .script, script: "output = input.replace(/\\w\\S*/g, w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())"),
        Action(id: UUID(), name: "Lower Case", type: .script, script: "output = input.toLowerCase()"),
        Action(id: UUID(), name: "Upper Case", type: .script, script: "output = input.toUpperCase()"),
        Action(id: UUID(), name: "Snake Case", type: .script, script: "output = input.trim().replace(/[\\s-]+/g, '_').replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase()"),
        Action(id: UUID(), name: "Kebab Case", type: .script, script: "output = input.trim().replace(/[\\s_]+/g, '-').replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase()"),
    ]
}

@Observable
@MainActor
final class ActionService {

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

    func processAction(_ action: Action, text: String) async {
        switch action.type {
        case .llm:
            await processLLMAction(action, text: text)
        case .script:
            await processScriptAction(action, text: text)
        }
    }

    private func processLLMAction(_ action: Action, text: String) async {
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
            let stream = ai.generateStream(prompt: action.prompt.replacingOccurrences(of: "{{input}}", with: text))
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

    private func processScriptAction(_ action: Action, text: String) async {
        status = .processing(original: text, result: "")

        do {
            let result = try await runScript(action.script, input: text)
            editedResult = result
            status = .ready(original: text, result: result)
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func runScript(_ script: String, input: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let lock = NSLock()

            func resumeOnce(with result: Result<String, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                continuation.resume(with: result)
            }

            let workItem = DispatchWorkItem {
                let context = JSContext()!
                context.setObject(input, forKeyedSubscript: "input" as NSString)

                var jsError: String?
                context.exceptionHandler = { _, exception in
                    jsError = exception?.toString() ?? "Unknown script error"
                }

                context.evaluateScript(script)

                if let jsError {
                    resumeOnce(with: .failure(ScriptError.executionFailed(jsError)))
                    return
                }

                guard let output = context.objectForKeyedSubscript("output"),
                      !output.isUndefined, !output.isNull else {
                    resumeOnce(with: .failure(ScriptError.noOutput))
                    return
                }

                resumeOnce(with: .success(output.toString() ?? ""))
            }

            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)

            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(5)) {
                resumeOnce(with: .failure(ScriptError.timeout))
            }
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

    func perform(_ action: Action) async {
        guard let text = await copySelectedText() else { return }
        await processAction(action, text: text)
        guard case .ready = status else { return }
        await applyResult()
    }
}

enum ScriptError: LocalizedError {
    case executionFailed(String)
    case noOutput
    case timeout

    var errorDescription: String? {
        switch self {
        case .executionFailed(let message): "Script error: \(message)"
        case .noOutput: "Script did not set 'output' variable"
        case .timeout: "Script timed out (5s limit)"
        }
    }
}
