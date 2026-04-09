import SwiftUI

struct TextActionPanelView: View {
    let service: TextActionService
    let onClose: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            switch service.status {
            case .idle:
                actionGrid
            case .copying:
                statusLabel("Copying...", systemImage: "doc.on.clipboard")
            case .processing(_, let result):
                previewArea(result, isStreaming: true)
            case .ready(_, let result):
                previewArea(result, isStreaming: false)
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

    private var actionGrid: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(TextAction.allCases) { action in
                Button {
                    triggerAction(action)
                } label: {
                    Text(action.rawValue)
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
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

    // MARK: - Confirm Bar

    private var confirmBar: some View {
        HStack {
            Button("Dismiss") { onDismiss() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Spacer()
            Button("Apply") {
                Task {
                    await service.applyResult()
                    onClose()
                }
            }
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

    // MARK: - Actions

    private func triggerAction(_ action: TextAction) {
        Task {
            guard let text = await service.copySelectedText() else { return }
            await service.processAction(action, text: text)
        }
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
