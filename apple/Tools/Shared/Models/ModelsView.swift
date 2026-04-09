import SwiftUI

struct ModelsView: View {
    @Environment(ModelStore.self) private var store

    var body: some View {
        List(ModelStore.available) { model in
            let state = store.downloadStates[model.id] ?? .notDownloaded

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                    Text(model.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if state == .downloaded, store.selectedModelID == model.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }

                switch state {
                case .notDownloaded:
                    Button {
                        // TODO: Surface download errors to the user
                        Task { try? await store.download(model) }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .buttonStyle(.borderless)

                case .downloading(let fraction):
                    ProgressView(value: fraction)
                        .frame(width: 60)

                case .downloaded:
                    Menu {
                        if store.selectedModelID != model.id {
                            Button("Select") {
                                store.selectedModelID = model.id
                            }
                        }
                        Button("Delete", role: .destructive) {
                            try? store.deleteDownload(model)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                if state == .downloaded {
                    store.selectedModelID = model.id
                }
            }
        }
        .navigationTitle("Models")
    }
}

#Preview {
    ModelsView()
        .environment(ModelStore())
}
