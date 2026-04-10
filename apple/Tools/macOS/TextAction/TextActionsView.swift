import SwiftUI

struct TextActionsView: View {
    @Environment(TextActionStore.self) private var store
    @State private var editingAction: TextAction?
    @State private var isAddingNew = false
    @State private var showResetConfirmation = false

    var body: some View {
        @Bindable var store = store
        List {
            ForEach(Array(store.actions.enumerated()), id: \.element.id) { index, action in
                HStack {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.name)
                        Text(action.instruction)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Menu {
                        Button("Edit") {
                            editingAction = action
                        }
                        Button("Delete", role: .destructive) {
                            if let idx = store.actions.firstIndex(where: { $0.id == action.id }) {
                                store.delete(at: IndexSet(integer: idx))
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    editingAction = action
                }
            }
            .onMove { store.move(from: $0, to: $1) }
        }
        .toolbar {
            ToolbarItem {
                Button("Reset to Defaults") {
                    showResetConfirmation = true
                }
            }
            ToolbarItem {
                Button {
                    isAddingNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingAction) { action in
            TextActionEditorSheet(action: action) { updated in
                store.update(updated)
                editingAction = nil
            } onCancel: {
                editingAction = nil
            }
        }
        .sheet(isPresented: $isAddingNew) {
            TextActionEditorSheet(action: TextAction(id: UUID(), name: "", instruction: "")) { newAction in
                store.add(newAction)
                isAddingNew = false
            } onCancel: {
                isAddingNew = false
            }
        }
        .navigationTitle("Text Actions")
        .alert("Reset to Defaults?", isPresented: $showResetConfirmation) {
            Button("Reset", role: .destructive) { store.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will replace all your custom actions with the defaults.")
        }
    }

}

private struct TextActionEditorSheet: View {
    @State var action: TextAction
    let onSave: (TextAction) -> Void
    let onCancel: () -> Void

    private var isValid: Bool {
        !action.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !action.instruction.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(action.name.isEmpty ? "New Action" : "Edit Action")
                .font(.headline)

            TextField("Name", text: $action.name)
                .textFieldStyle(.roundedBorder)

            Text("Instruction")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextEditor(text: $action.instruction)
                .font(.body)
                .frame(minHeight: 80)
                .border(Color.secondary.opacity(0.2))

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { onSave(action) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
