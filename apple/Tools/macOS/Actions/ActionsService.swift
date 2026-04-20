import Foundation
import JavaScriptCore

@Observable
@MainActor
final class ActionsService {

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
    private let hfService: HFService
    private let modelIDProvider: () -> String
    private var savedClipboard: String?
    private var currentTask: Task<Void, Never>?

    init(llm: LLMService, hfService: HFService, modelIDProvider: @escaping () -> String) {
        self.llm = llm
        self.hfService = hfService
        self.modelIDProvider = modelIDProvider
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
        let modelID = modelIDProvider()
        guard hfService.isModelReady(id: modelID) else {
            throw LLMRunError.noModel
        }

        let modelDir = hfService.modelDirectory(for: modelID)
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
