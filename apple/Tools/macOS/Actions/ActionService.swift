import Foundation
import JavaScriptCore

struct Action: Codable, Identifiable, Equatable {

    enum ActionType: String, Codable, CaseIterable {
        case llm
        case js
        case workflow
    }

    struct Step: Codable, Identifiable, Equatable {
        var id: UUID
        var name: String
        var type: ActionType
        var prompt: String
        var script: String

        init(id: UUID = UUID(), name: String = "", type: ActionType = .llm, prompt: String = "", script: String = "") {
            self.id = id
            self.name = name
            self.type = type
            self.prompt = prompt
            self.script = script
        }
    }

    var id: UUID
    var name: String
    var type: ActionType
    var prompt: String
    var script: String
    var steps: [Step]

    init(id: UUID = UUID(), name: String = "", type: ActionType = .llm, prompt: String = "", script: String = "", steps: [Step] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.prompt = prompt
        self.script = script
        self.steps = steps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(ActionType.self, forKey: .type) ?? .llm
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        script = try container.decodeIfPresent(String.self, forKey: .script) ?? ""
        steps = try container.decodeIfPresent([Step].self, forKey: .steps) ?? []
    }

    func copy(id: UUID = UUID()) -> Action {
        Action(id: id, name: name, type: type, prompt: prompt, script: script, steps: steps.map {
            Step(name: $0.name, type: $0.type, prompt: $0.prompt, script: $0.script)
        })
    }

    var duplicateStepNames: Set<String> {
        let names = steps.map(\.name).filter { !$0.isEmpty }
        var seen = Set<String>()
        var dupes = Set<String>()
        for name in names {
            if !seen.insert(name).inserted { dupes.insert(name) }
        }
        return dupes
    }

    var hasValidStepNames: Bool {
        duplicateStepNames.isEmpty && steps.allSatisfy { !$0.name.isEmpty }
    }

    static let defaultNames: Set<String> = ["Fix grammar", "Summarize", "Translate to English", "Sort lines", "Count characters"]
    static let defaults: [Action] = templates.filter { defaultNames.contains($0.name) }.map { $0.copy() }

    static let templates: [Action] = [
        // LLM
        Action(id: UUID(), name: "Fix grammar", prompt: "Fix grammar and spelling errors. Preserve the original language, tone, and formatting. If already correct, return unchanged. Output ONLY the result.\n\n\"\"\"\n{{input}}\n\"\"\""),
        Action(id: UUID(), name: "Summarize", prompt: "Summarize in 2-3 sentences. Respond in the same language as the input. Output ONLY the summary.\n\n\"\"\"\n{{input}}\n\"\"\""),
        Action(id: UUID(), name: "Translate to English", prompt: "Translate to English. Preserve the original formatting. If already in English, return unchanged. Output ONLY the translation.\n\n\"\"\"\n{{input}}\n\"\"\""),
        Action(id: UUID(), name: "Make concise", prompt: "Rewrite to be shorter while preserving the full meaning. Remove filler words and redundancy. Respond in the same language as the input. Output ONLY the result.\n\n\"\"\"\n{{input}}\n\"\"\""),
        Action(id: UUID(), name: "Professional tone", prompt: "Rewrite in a clear, professional tone suitable for work communication. Preserve the original meaning and language. Output ONLY the result.\n\n\"\"\"\n{{input}}\n\"\"\""),
        Action(id: UUID(), name: "Friendly tone", prompt: "Rewrite in a warm, conversational tone. Preserve the original meaning and language. Output ONLY the result.\n\n\"\"\"\n{{input}}\n\"\"\""),
        Action(id: UUID(), name: "Extract key points", prompt: "Extract the key points as a concise bulleted list. Respond in the same language as the input. Output ONLY the list.\n\n\"\"\"\n{{input}}\n\"\"\""),
        Action(id: UUID(), name: "Explain simply", prompt: "Explain this in plain, simple language that anyone can understand. Respond in the same language as the input. Output ONLY the explanation.\n\n\"\"\"\n{{input}}\n\"\"\""),
        // Script
        Action(id: UUID(), name: "Sort lines", type: .js, script: "output = input.split('\\n').sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' })).join('\\n')"),
        Action(id: UUID(), name: "Count characters", type: .js, script: "output = input.length"),
        Action(id: UUID(), name: "Count lines", type: .js, script: "output = input.split('\\n').length"),
        Action(id: UUID(), name: "Count words", type: .js, script: "output = input.trim().split(/\\s+/).length"),
        Action(id: UUID(), name: "Lower case", type: .js, script: "output = input.toLowerCase()"),
        Action(id: UUID(), name: "Upper case", type: .js, script: "output = input.toUpperCase()"),
        // Workflow
        Action(id: UUID(), name: "Polish & Trim", type: .workflow, steps: [
            Action.Step(name: "Polish", type: .llm, prompt: "Fix grammar and improve clarity. Preserve the original language and meaning. Output ONLY the result.\n\n\"\"\"\n{{input}}\n\"\"\""),
            Action.Step(name: "Trim", type: .js, script: "output = Polish.trim()"),
        ]),
    ]
}

@Observable
@MainActor
final class ActionService {

    enum Status: Equatable {
        case idle
        case copying
        case processing(original: String, result: String)
        case processingWorkflow(original: String, stepIndex: Int, stepCount: Int, stepName: String, result: String)
        case ready(original: String, result: String)
        case pasting
        case error(String)
    }

    private(set) var status: Status = .idle
    var editedResult = ""
    var selectedActionIndex = 0

    private let clipboard = ClipboardService()
    private let llm: LLMService
    private let modelStore: ModelStore
    private var savedClipboard: String?
    private var currentTask: Task<Void, Never>?

    init(llm: LLMService, modelStore: ModelStore) {
        self.llm = llm
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
        case .js:
            await processScriptAction(action, text: text)
        case .workflow:
            await processWorkflow(action, text: text)
        }
    }

    private func processLLMAction(_ action: Action, text: String) async {
        status = .processing(original: text, result: "")
        do {
            let result = try await runLLM(prompt: substituteVariables(in: action.prompt, variables: ["input": text])) { partial in
                self.status = .processing(original: text, result: partial)
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
            let result = try await runScript(action.script, variables: ["input": text])
            editedResult = result
            status = .ready(original: text, result: result)
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func processWorkflow(_ action: Action, text: String) async {
        let steps = action.steps
        guard !steps.isEmpty else {
            status = .error("Workflow has no steps")
            return
        }

        var outputs: [String: String] = ["input": text]
        var lastResult = ""

        for (index, step) in steps.enumerated() {
            guard !Task.isCancelled else { return }

            status = .processingWorkflow(original: text, stepIndex: index, stepCount: steps.count, stepName: step.name, result: "")

            do {
                let result: String
                switch step.type {
                case .llm:
                    let prompt = substituteVariables(in: step.prompt, variables: outputs)
                    result = try await runLLM(prompt: prompt) { partial in
                        self.status = .processingWorkflow(original: text, stepIndex: index, stepCount: steps.count, stepName: step.name, result: partial)
                    }
                case .js:
                    result = try await runScript(step.script, variables: outputs)
                case .workflow:
                    status = .error("Nested workflows are not supported")
                    return
                }

                lastResult = result
                if !step.name.isEmpty {
                    outputs[step.name] = result
                }
            } catch {
                status = .error("Step \"\(step.name)\" failed: \(error.localizedDescription)")
                return
            }
        }

        editedResult = lastResult
        status = .ready(original: text, result: lastResult)
    }

    // MARK: - Execution Primitives

    private func runLLM(prompt: String, onChunk: @escaping (String) -> Void) async throws -> String {
        guard modelStore.isModelDownloaded(for: .actionPanel) else {
            throw LLMRunError.noModel
        }

        let modelID = modelStore.modelID(for: .actionPanel)
        let modelDir = modelStore.modelDirectory(for: modelID)
        try await llm.loadModel(id: modelID, directory: modelDir)

        var result = ""
        let stream = llm.generateStream(prompt: prompt)
        for try await chunk in stream {
            result += chunk
            onChunk(result)
        }
        return result
    }

    private func substituteVariables(in template: String, variables: [String: String]) -> String {
        var result = template
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    private func runScript(_ script: String, variables: [String: String]) async throws -> String {
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
                for (key, value) in variables {
                    context.setObject(value, forKeyedSubscript: key as NSString)
                }

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

private enum LLMRunError: LocalizedError {
    case noModel

    var errorDescription: String? {
        switch self {
        case .noModel: "No model downloaded"
        }
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
