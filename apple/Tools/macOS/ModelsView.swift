import SwiftUI

struct ModelsView: View {
    @Environment(ModelStore.self) private var store
    @State private var errorMessage: String?

    var body: some View {
        List(ModelStore.available) { model in
            let state = store.downloadStates[model.id] ?? .notDownloaded

            HStack {
                Image(model.avatar)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(model.name)
                        switch model.kind {
                        case .vlm: Text("Vision").badgeStyle()
                        case .stt: Text("Speech").badgeStyle()
                        case .llm: EmptyView()
                        }
                    }
                    Text("\(model.summary) · \(model.size)")
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
                        Task {
                            do {
                                try await store.download(model)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
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
        .alert("Download Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .navigationTitle("Models")
        .toolbar {
            Button {
                NSWorkspace.shared.open(store.cacheDirectory)
            } label: {
                Image(systemName: "folder")
            }
            .help("Show in Finder")
        }
    }
}

#Preview {
    ModelsView()
        .environment(ModelStore())
}
