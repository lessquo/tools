import SwiftUI

struct ActionsView: View {
    @Environment(ActionStore.self) private var store
    @State private var selectedActionID: UUID?
    @State private var focusNewActionID: UUID?
    @State private var showResetConfirmation = false

    var body: some View {
        HSplitView {
            List(selection: $selectedActionID) {
                ForEach(Array(store.actions.enumerated()), id: \.element.id) { index, action in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 16, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(action.name.isEmpty ? "Untitled" : action.name)
                                if action.type == .script {
                                    Text("JS")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(.secondary.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                            }
                            Text(action.type == .llm ? action.instruction : action.script)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .tag(action.id)
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            delete(action)
                        }
                    }
                }
                .onMove { store.move(from: $0, to: $1) }
            }
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
            .onDeleteCommand {
                if let id = selectedActionID,
                   let action = store.actions.first(where: { $0.id == id }) {
                    delete(action)
                }
            }

            if let selectedID = selectedActionID,
               let action = store.actions.first(where: { $0.id == selectedID }) {
                ActionDetailView(action: action, focusName: focusNewActionID == selectedID)
                    .id(selectedID)
                    .onAppear { focusNewActionID = nil }
                    .frame(minWidth: 300, maxWidth: .infinity)
            } else if store.actions.isEmpty {
                ContentUnavailableView(
                    "No Actions",
                    systemImage: "bolt",
                    description: Text("Press ⌘N to create an action")
                )
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "bolt",
                    description: Text("Select an action to edit")
                )
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Reset to Defaults") {
                    showResetConfirmation = true
                }
            }
            ToolbarItem {
                Button {
                    addNew()
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .navigationTitle("Actions")
        .alert("Reset to Defaults?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) {
                store.resetToDefaults()
                selectedActionID = store.actions.first?.id
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace all your custom actions with the defaults.")
        }
        .task {
            if selectedActionID == nil {
                selectedActionID = store.actions.first?.id
            }
        }
    }

    private func addNew() {
        let action = Action(id: UUID(), name: "", instruction: "")
        store.add(action)
        focusNewActionID = action.id
        selectedActionID = action.id
    }

    private func delete(_ action: Action) {
        guard let idx = store.actions.firstIndex(where: { $0.id == action.id }) else { return }
        let wasSelected = selectedActionID == action.id
        store.delete(at: IndexSet(integer: idx))
        if wasSelected {
            let newIndex = min(idx, store.actions.count - 1)
            selectedActionID = newIndex >= 0 ? store.actions[newIndex].id : nil
        }
    }
}

private struct ActionDetailView: View {
    @Environment(ActionStore.self) private var store
    @State private var draft: Action
    @FocusState private var isNameFocused: Bool
    let focusName: Bool

    init(action: Action, focusName: Bool) {
        self._draft = State(initialValue: action)
        self.focusName = focusName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: $draft.name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)

            Picker("Type", selection: $draft.type) {
                Text("LLM").tag(Action.ActionType.llm)
                Text("Script").tag(Action.ActionType.script)
            }
            .pickerStyle(.segmented)
            .fixedSize()

            switch draft.type {
            case .llm:
                Text("Instruction")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft.instruction)
                    .font(.body)
            case .script:
                Text("JavaScript — read `input`, set `output`")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft.script)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .padding()
        .onAppear {
            if focusName {
                isNameFocused = true
            }
        }
        .onChange(of: draft) { _, newValue in
            store.update(newValue)
        }
    }
}

#Preview {
    ActionsView()
        .environment(ActionStore())
}
