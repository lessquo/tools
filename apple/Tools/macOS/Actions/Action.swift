import Foundation

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
