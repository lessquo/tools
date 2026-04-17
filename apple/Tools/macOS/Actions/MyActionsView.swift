import SwiftUI

@Observable
@MainActor
final class MyActionsViewState {
    var selectedActionIDs: Set<UUID> = []
}

struct MyActionsView: View {
    @Environment(ActionStore.self) private var store
    @Environment(MyActionsViewState.self) private var state
    @State private var focusNewActionID: UUID?

    var body: some View {
        @Bindable var state = state
        HSplitView {
            List(selection: $state.selectedActionIDs) {
                ForEach(store.actions) { action in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.name.isEmpty ? "Untitled" : action.name)
                        Text(actionSubtitle(action))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(action.id)
                    .padding(.vertical, 4)
                    .contextMenu {
                        if state.selectedActionIDs.contains(action.id),
                           state.selectedActionIDs.count > 1 {
                            Button("Delete \(state.selectedActionIDs.count) Actions", role: .destructive) {
                                deleteSelected()
                            }
                        } else {
                            Button("Duplicate") {
                                if let newID = store.duplicate(action) {
                                    state.selectedActionIDs = [newID]
                                }
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

            if state.selectedActionIDs.count > 1 {
                MultiSelectionView(
                    actions: store.actions.filter { state.selectedActionIDs.contains($0.id) },
                    buttonLabel: "Delete Selected",
                    buttonIcon: "trash",
                    buttonRole: .destructive
                ) {
                    deleteSelected()
                }
                .frame(minWidth: 300, maxWidth: .infinity)
            } else if let selectedID = state.selectedActionIDs.first,
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
            if state.selectedActionIDs.isEmpty {
                if let firstID = store.actions.first?.id {
                    state.selectedActionIDs = [firstID]
                }
            }
        }
    }

    private func actionSubtitle(_ action: Action) -> String {
        "\(action.steps.count) step\(action.steps.count == 1 ? "" : "s")"
    }

    private func addNew() {
        let action = Action(id: UUID(), name: "")
        store.add(action)
        focusNewActionID = action.id
        state.selectedActionIDs = [action.id]
    }

    private func delete(_ action: Action) {
        guard let idx = store.actions.firstIndex(where: { $0.id == action.id }) else { return }
        let wasSelected = state.selectedActionIDs.contains(action.id)
        store.delete(at: IndexSet(integer: idx))
        if wasSelected {
            state.selectedActionIDs.remove(action.id)
            if state.selectedActionIDs.isEmpty {
                let newIndex = min(idx, store.actions.count - 1)
                if newIndex >= 0 {
                    state.selectedActionIDs = [store.actions[newIndex].id]
                }
            }
        }
    }

    private func deleteSelected() {
        guard !state.selectedActionIDs.isEmpty else { return }
        let ids = state.selectedActionIDs
        let firstIdx = store.actions.firstIndex { ids.contains($0.id) } ?? 0
        store.delete(ids: ids)
        state.selectedActionIDs = []
        if !store.actions.isEmpty {
            let newIndex = min(firstIdx, store.actions.count - 1)
            state.selectedActionIDs = [store.actions[newIndex].id]
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
                .font(.title2.bold())
                .textFieldStyle(.plain)
                .focused($isNameFocused)

            StepsView(steps: $draft.steps)
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
