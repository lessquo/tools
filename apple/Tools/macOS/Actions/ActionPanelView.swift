import SwiftUI

struct ActionPanelView: View {
    @Bindable var service: ActionService
    @FocusState private var isEditorFocused: Bool
    @State private var editorMeasuredHeight: CGFloat = 0
    let onClose: () -> Void
    let onDismiss: () -> Void
    let onMakeKey: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            switch service.status {
            case .idle, .copying:
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
        .modifier(GlassBackgroundModifier())
    }

    // MARK: - Preview

    private func previewArea(_ text: String, isStreaming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 5)
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
            .frame(height: min(max(editorMeasuredHeight, 24), 300))
            .background(
                Text(service.editedResult.isEmpty ? " " : service.editedResult)
                    .font(.body)
                    .padding(.horizontal, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: EditorHeightKey.self,
                                value: geo.size.height
                            )
                        }
                    )
                    .hidden()
            )
            .onPreferenceChange(EditorHeightKey.self) { editorMeasuredHeight = $0 }
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
            Button("\(service.currentApplyMode == .replace ? "Replace" : "Append") ⌘↩") {
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

private struct EditorHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Glass Background

private struct GlassBackgroundModifier: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 12)

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(VisualEffectBackground())
                .clipShape(shape)
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sheet
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
