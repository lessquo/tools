import Foundation
import JavaScriptCore

struct Action: Codable, Identifiable, Equatable {

    struct Step: Codable, Identifiable, Equatable {
        enum Kind: String, Codable, CaseIterable {
            case llm
            case js
        }

        var id: UUID
        var name: String
        var type: Kind
        var prompt: String
        var script: String

        init(id: UUID = UUID(), name: String = "", type: Kind = .llm, prompt: String = "", script: String = "") {
            self.id = id
            self.name = name
            self.type = type
            self.prompt = prompt
            self.script = script
        }
    }

    var id: UUID
    var name: String
    var steps: [Step]

    init(id: UUID = UUID(), name: String = "", steps: [Step] = [Step()]) {
        self.id = id
        self.name = name
        self.steps = steps
    }

    func copy(id: UUID = UUID()) -> Action {
        Action(id: id, name: name, steps: steps.map {
            Step(name: $0.name, type: $0.type, prompt: $0.prompt, script: $0.script)
        })
    }

    static let defaultNames: Set<String> = ["Fix grammar", "Summarize", "Translate to English", "Sort lines", "Count"]
    static let defaults: [Action] = templates.filter { defaultNames.contains($0.name) }.map { $0.copy() }

    static let templates: [Action] = [
        Action(id: UUID(), name: "Fix grammar", steps: [
            Step(name: "Fix", type: .llm, prompt: "Fix grammar and spelling errors. Preserve the original language, tone, and formatting. If already correct, return unchanged. Output ONLY the result.\n\n\"\"\"\n{{input}}\n\"\"\""),
            Step(name: "Trim", type: .js, script: "output = Fix.trim()"),
        ]),
        Action(id: UUID(), name: "Summarize", steps: [
            Step(name: "Summary", type: .llm, prompt: "Summarize in 2-3 sentences. Respond in the same language as the input. Output ONLY the summary.\n\n\"\"\"\n{{input}}\n\"\"\""),
        ]),
        Action(id: UUID(), name: "Sort lines", steps: [
            Step(name: "Sort", type: .js, script: "output = input.split('\\n').sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' })).join('\\n')"),
        ]),
        Action(id: UUID(), name: "Count", steps: [
            Step(name: "Count", type: .js, script: "output = `${input.length} characters, ${input.trim().split(/\\s+/).length} words, ${input.split('\\n').length} lines`"),
        ]),
        Action(id: UUID(), name: "Lower case", steps: [
            Step(name: "Lower", type: .js, script: "output = input.toLowerCase()"),
        ]),
        Action(id: UUID(), name: "Upper case", steps: [
            Step(name: "Upper", type: .js, script: "output = input.toUpperCase()"),
        ]),
    ]
}

@Observable
@MainActor
final class ActionService {

    enum Status: Equatable {
        case idle
        case copying
        case processing(original: String, stepIndex: Int, stepCount: Int, stepName: String, result: String)
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
        guard PermissionsService.isAccessibilityGranted else {
            PermissionsService.requestAccessibility()
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
        let steps = action.steps
        guard !steps.isEmpty else {
            status = .error("Action has no steps")
            return
        }

        var outputs: [String: String] = ["input": text]
        var lastResult = ""

        for (index, step) in steps.enumerated() {
            guard !Task.isCancelled else { return }

            status = .processing(original: text, stepIndex: index, stepCount: steps.count, stepName: step.name, result: "")

            do {
                let result: String
                switch step.type {
                case .llm:
                    let prompt = substituteVariables(in: step.prompt, variables: outputs)
                    result = try await runLLM(prompt: prompt) { partial in
                        self.status = .processing(original: text, stepIndex: index, stepCount: steps.count, stepName: step.name, result: partial)
                    }
                case .js:
                    result = try await runScript(step.script, variables: outputs)
                }

                lastResult = result
                if !step.name.isEmpty {
                    outputs[step.name] = result
                }
            } catch {
                let label = step.name.isEmpty ? "Step \(index + 1)" : "Step \"\(step.name)\""
                status = .error("\(label) failed: \(error.localizedDescription)")
                return
            }
        }

        editedResult = lastResult
        status = .ready(original: text, result: lastResult)
    }

    // MARK: - Execution Primitives

    private func runLLM(prompt: String, onChunk: @escaping (String) -> Void) async throws -> String {
        guard modelStore.isModelDownloaded(for: .quickActions) else {
            throw LLMRunError.noModel
        }

        let modelID = modelStore.modelID(for: .quickActions)
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
