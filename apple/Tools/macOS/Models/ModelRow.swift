import HuggingFace
import SwiftUI

struct ModelRow: View {
    @Environment(ModelStore.self) private var store
    let model: HuggingFace.Model
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
                Text(model.id.name)
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
                    store.startDownload(model)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)

            case .downloading(let fraction):
                ProgressView(value: fraction)
                    .frame(width: 60)
                Button {
                    store.cancelDownload(model)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)

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
                    Divider()
                    Link("View on Hugging Face", destination: URL(string: "https://huggingface.co/\(modelID)")!)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
        }
        .padding(.vertical, 4)
        .tag(model.id)
        .contextMenu {
            switch state {
            case .notDownloaded:
                Button("Download") {
                    store.startDownload(model)
                }
            case .downloading:
                Button("Cancel Download") {
                    store.cancelDownload(model)
                }
            case .downloaded:
                if store.selectedModelID != modelID {
                    Button("Select") {
                        store.selectedModelID = modelID
                    }
                }
                Button("Delete", role: .destructive) {
                    try? store.deleteDownload(model)
                }
            }
            Divider()
            Link("View on Hugging Face", destination: URL(string: "https://huggingface.co/\(modelID)")!)
        }
    }
}
