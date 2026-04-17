import SwiftUI

struct CloudView: View {
    @Environment(CloudStore.self) private var store

    var body: some View {
        Form {
            ForEach(CloudStore.Provider.allCases) { provider in
                Section(provider.label) {
                    ProviderRow(provider: provider)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ProviderRow: View {
    @Environment(CloudStore.self) private var store
    @State private var isRevealed = false
    let provider: CloudStore.Provider

    private var hasKey: Bool { !(store.apiKeys[provider] ?? "").isEmpty }

    var body: some View {
        Group {
            if isRevealed {
                HStack {
                    SecureField(provider.apiKeyName, text: Binding(
                        get: { store.apiKeys[provider] ?? "" },
                        set: { store.setAPIKey($0, for: provider) }
                    ))
                    Button("Save") {
                        store.saveAPIKey(for: provider)
                        isRevealed = false
                        Task { await store.fetchModels(for: provider) }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                HStack {
                    Text(provider.apiKeyName).foregroundStyle(.secondary)
                    Spacer()
                    Button(hasKey ? "Edit" : "Add") {
                        isRevealed = true
                    }
                }
            }

            switch store.fetchStates[provider] ?? .idle {
            case .idle:
                EmptyView()
            case .loading:
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Loading models…").foregroundStyle(.secondary)
                }
            case .loaded:
                let models = store.availableModels[provider] ?? []
                if models.isEmpty {
                    Text("No models available").foregroundStyle(.secondary)
                } else {
                    ForEach(models, id: \.self) { model in
                        Text(model).monospaced()
                    }
                }
            case .failed(let message):
                Text(message).foregroundStyle(.red)
            }
        }
        .task {
            if hasKey, store.fetchStates[provider] == .idle {
                await store.fetchModels(for: provider)
            }
        }
    }
}

#Preview {
    CloudView()
        .environment(CloudStore())
}
