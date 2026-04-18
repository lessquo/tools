import SwiftUI

struct APIKeysView: View {
    @Environment(APIKeyStore.self) private var store

    var body: some View {
        Form {
            ForEach(APIKeyStore.Provider.allCases) { provider in
                Section {
                    ProviderRow(provider: provider)
                } header: {
                    HStack {
                        Image(provider.rawValue)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(provider.label)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("API Keys")
    }
}

private struct ProviderRow: View {
    @Environment(APIKeyStore.self) private var store
    @State private var isRevealed = false
    @FocusState private var isFieldFocused: Bool
    let provider: APIKeyStore.Provider

    private var hasKey: Bool { !(store.apiKeys[provider] ?? "").isEmpty }

    var body: some View {
        Group {
            if isRevealed {
                HStack {
                    SecureField(provider.apiKeyName, text: Binding(
                        get: { store.apiKeys[provider] ?? "" },
                        set: { store.setAPIKey($0, for: provider) }
                    ))
                    .focused($isFieldFocused)
                    .onAppear { isFieldFocused = true }
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
                    StatusIndicator(state: store.fetchStates[provider] ?? .idle)
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

private struct StatusIndicator: View {
    let state: APIKeyStore.FetchState

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView().controlSize(.small)
        case .loaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .help("Connected")
        case .failed(let message):
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .help(message)
        }
    }
}

#Preview {
    APIKeysView()
        .environment(APIKeyStore())
}
