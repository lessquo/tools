import SwiftUI

struct MyActionsView: View {
    @Environment(ActionStore.self) private var store
    @State private var focusNewActionID: UUID?

    var body: some View {
        @Bindable var store = store
        HSplitView {
            List(selection: $store.selectedActionIDs) {
                ForEach(store.actions) { action in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(action.name.isEmpty ? "Untitled" : action.name)
                            if action.type == .script {
                                Text("JS").badgeStyle()
                            }
                        }
                        Text(action.type == .llm ? action.prompt : action.script)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(action.id)
                    .padding(.vertical, 4)
                    .contextMenu {
                        if store.selectedActionIDs.contains(action.id),
                           store.selectedActionIDs.count > 1 {
                            Button("Delete \(store.selectedActionIDs.count) Actions", role: .destructive) {
                                deleteSelected()
                            }
                        } else {
                            Button("Duplicate") {
                                store.duplicate(action)
                            }
                            Button("Delete", role: .destructive) {
                                delete(action)
                            }
                        }
                    }
                }
                .onMove { store.move(from: $0, to: $1) }
            }
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
            .onDeleteCommand {
                deleteSelected()
            }

            if store.selectedActionIDs.count > 1 {
                MultiSelectionView(
                    actions: store.actions.filter { store.selectedActionIDs.contains($0.id) },
                    buttonLabel: "Delete Selected",
                    buttonIcon: "trash",
                    buttonRole: .destructive
                ) {
                    deleteSelected()
                }
                .frame(minWidth: 300, maxWidth: .infinity)
            } else if let selectedID = store.selectedActionIDs.first,
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
                Button {
                    addNew()
                } label: {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .task {
            if store.selectedActionIDs.isEmpty {
                if let firstID = store.actions.first?.id {
                    store.selectedActionIDs = [firstID]
                }
            }
        }
    }

    private func addNew() {
        let action = Action(id: UUID(), name: "", prompt: "")
        store.add(action)
        focusNewActionID = action.id
        store.selectedActionIDs = [action.id]
    }

    private func delete(_ action: Action) {
        guard let idx = store.actions.firstIndex(where: { $0.id == action.id }) else { return }
        let wasSelected = store.selectedActionIDs.contains(action.id)
        store.delete(at: IndexSet(integer: idx))
        if wasSelected {
            store.selectedActionIDs.remove(action.id)
            if store.selectedActionIDs.isEmpty {
                let newIndex = min(idx, store.actions.count - 1)
                if newIndex >= 0 {
                    store.selectedActionIDs = [store.actions[newIndex].id]
                }
            }
        }
    }

    private func deleteSelected() {
        guard !store.selectedActionIDs.isEmpty else { return }
        let ids = store.selectedActionIDs
        let firstIdx = store.actions.firstIndex { ids.contains($0.id) } ?? 0
        store.delete(ids: ids)
        store.selectedActionIDs = []
        if !store.actions.isEmpty {
            let newIndex = min(firstIdx, store.actions.count - 1)
            store.selectedActionIDs = [store.actions[newIndex].id]
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
                Text("Prompt — use {{input}} for selected text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft.prompt)
                    .font(.body)
            case .script:
                Text("JavaScript — read `input`, set `output`")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft.script)
                    .font(.system(.body, design: .monospaced))
                ScriptPreviewView(script: draft.script)
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
