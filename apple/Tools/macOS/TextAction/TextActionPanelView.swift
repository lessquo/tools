import SwiftUI

struct TextActionPanelView: View {
    @Bindable var service: TextActionService
    let actions: [TextAction]
    @FocusState private var isEditorFocused: Bool
    let onClose: () -> Void
    let onDismiss: () -> Void
    let onMakeKey: () -> Void
    let onTriggerAction: (TextAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            switch service.status {
            case .idle:
                if actions.isEmpty {
                    emptyState
                } else {
                    actionGrid
                }
            case .copying:
                statusLabel("Copying...", systemImage: "doc.on.clipboard")
            case .processing(_, let result):
                previewArea(result, isStreaming: true)
            case .ready:
                editablePreview
                confirmBar
            case .pasting:
                statusLabel("Applying...", systemImage: "doc.on.clipboard.fill")
            case .error(let message):
                errorView(message)
            }
        }
        .padding(12)
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Action Grid

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No actions configured.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Open Tools to add actions.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button("Dismiss") { onDismiss() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 8)
    }

    private var actionGrid: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                Button {
                    onTriggerAction(action)
                } label: {
                    HStack(spacing: 4) {
                        Text("\(index + 1)")
                            .foregroundStyle(.tertiary)
                        Text(action.name)
                        if action.type == .script {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(service.selectedActionIndex == index ? .accentColor : nil)
            }
        }
    }

    // MARK: - Preview

    private func previewArea(_ text: String, isStreaming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 300)

            if isStreaming {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { onDismiss() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    private var editablePreview: some View {
        TextEditor(text: $service.editedResult)
            .font(.body)
            .scrollContentBackground(.hidden)
            .frame(maxHeight: 300)
            .focused($isEditorFocused)
            .onAppear {
                onMakeKey()
                isEditorFocused = true
            }
    }

    // MARK: - Confirm Bar

    private var confirmBar: some View {
        HStack {
            Button("Dismiss") { onDismiss() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Spacer()
            Button("Apply ⌘↩") {
                onClose()
                Task {
                    await service.applyResult()
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.top, 8)
    }

    // MARK: - Status

    private func statusLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.vertical, 16)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.red)
            Button("Dismiss") { onDismiss() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Visual Effect Background

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
