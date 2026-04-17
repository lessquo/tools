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
    let provider: CloudStore.Provider

    private var apiKey: String { store.apiKeys[provider] ?? "" }

    var body: some View {
        Group {
            SecureField(provider.apiKeyName, text: Binding(
                get: { store.apiKeys[provider] ?? "" },
                set: { store.setAPIKey($0, for: provider) }
            ))

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
        .task(id: apiKey) {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            store.saveAPIKey(for: provider)
            await store.fetchModels(for: provider)
        }
    }
}

#Preview {
    CloudView()
        .environment(CloudStore())
}
