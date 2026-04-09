import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(ModelStore.self) private var modelStore
    @Environment(AIService.self) private var aiService
    @State private var textActionService: TextActionService?
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 4) {
            Menu("Text Action") {
                ForEach(TextAction.allCases) { action in
                    Button(action.rawValue) {
                        triggerAction(action)
                    }
                }
            }
            .disabled(isRunning || !modelStore.isSelectedModelDownloaded)

            if let service = textActionService {
                switch service.status {
                case .copying:
                    Label("Copying...", systemImage: "doc.on.clipboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .processing:
                    Label("Processing...", systemImage: "brain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .pasting:
                    Label("Pasting...", systemImage: "doc.on.clipboard.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .error(let message):
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                case .idle:
                    EmptyView()
                }
            }

            Divider()

            Button("Models...") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }

            SettingsLink {
                Text("Settings...")
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .padding(4)
    }

    private func triggerAction(_ action: TextAction) {
        let service = TextActionService(ai: aiService, modelStore: modelStore)
        textActionService = service
        isRunning = true
        Task {
            await service.perform(action)
            isRunning = false
        }
    }
}

#Preview {
    MenuBarView()
        .environment(ModelStore())
        .environment(AIService())
}
