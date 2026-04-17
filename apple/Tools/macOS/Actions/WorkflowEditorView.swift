import SwiftUI

struct WorkflowEditorView: View {
    @Binding var steps: [Action.Step]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Steps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    addBlankStep()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }

            if steps.isEmpty {
                Spacer()
            } else {
                List {
                    ForEach($steps) { $step in
                        StepEditorRow(
                            step: $step,
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
    let availableVariables: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Step name", text: $step.name)
                .font(.title3.bold())
                .textFieldStyle(.plain)

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
