import SwiftUI

struct WorkflowEditorView: View {
    @Binding var steps: [Action.Step]
    let duplicateNames: Set<String>
    @Environment(ActionStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Steps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Blank Step") { addBlankStep() }
                    let actions = store.actions.filter { $0.type != .workflow }
                    if !actions.isEmpty {
                        Divider()
                        ForEach(actions) { action in
                            Button(action.name.isEmpty ? "Untitled" : action.name) {
                                addStepFromAction(action)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if steps.isEmpty {
                Spacer()
            } else {
                List {
                    ForEach($steps) { $step in
                        StepEditorRow(
                            step: $step,
                            isDuplicateName: duplicateNames.contains(step.name),
                            availableVariables: availableVariables(before: step.id)
                        )
                    }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { steps.remove(atOffsets: $0) }
                }
            }
        }
    }

    private func addBlankStep() {
        steps.append(Action.Step())
    }

    private func addStepFromAction(_ action: Action) {
        steps.append(Action.Step(
            name: action.name,
            type: action.type,
            prompt: action.prompt,
            script: action.script
        ))
    }

    private func availableVariables(before stepID: UUID) -> [String] {
        var names = ["input"]
        for step in steps {
            if step.id == stepID { break }
            if !step.name.isEmpty {
                names.append(step.name)
            }
        }
        return names
    }
}

private struct StepEditorRow: View {
    @Binding var step: Action.Step
    let isDuplicateName: Bool
    let availableVariables: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Step name", text: $step.name)
                    .textFieldStyle(.roundedBorder)
                if isDuplicateName {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .help("Step names must be unique within a workflow")
                }
            }

            Picker("", selection: $step.type) {
                Text("LLM").tag(Action.ActionType.llm)
                Text("JS").tag(Action.ActionType.js)
            }
            .pickerStyle(.segmented)
            .fixedSize()

            switch step.type {
            case .llm:
                Text("Available: \(availableVariables.map { "{{" + $0 + "}}" }.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                TextEditor(text: $step.prompt)
                    .font(.body)
                    .frame(minHeight: 60, maxHeight: 120)
            case .js:
                Text("Variables: \(availableVariables.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                TextEditor(text: $step.script)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 60, maxHeight: 120)
            case .workflow:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }
}
