import HuggingFace
import SwiftUI

struct ModelRow: View {
    @Environment(ModelStore.self) private var store
    let model: HuggingFace.Model
    @Binding var errorMessage: String?

    var body: some View {
        let modelID = model.id.rawValue
        let state = store.downloadStates[modelID] ?? .notDownloaded

        HStack {
            Group {
                if model.avatar.isEmpty {
                    Image(systemName: "cube.box")
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(model.avatar)
                        .resizable()
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(model.id.name)
                    if let tag = model.pipelineTag {
                        Text(tag).badgeStyle()
                    }
                }
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.to.line")
                            .imageScale(.small)
                        Text((model.downloads ?? 0).compactFormatted)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "heart")
                            .imageScale(.small)
                        Text((model.likes ?? 0).compactFormatted)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if state == .downloaded, store.selectedModelID == modelID {
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
                    if store.selectedModelID != modelID {
                        Button("Select") {
                            store.selectedModelID = modelID
                        }
                    }
                    Button("Delete", role: .destructive) {
                        try? store.deleteDownload(model)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if state == .downloaded {
                store.selectedModelID = modelID
            }
        }
    }
}
