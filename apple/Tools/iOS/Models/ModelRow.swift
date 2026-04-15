import HuggingFace
import SwiftUI

struct ModelRow: View {
    @Environment(ModelStore.self) private var store
    let model: HuggingFace.Model
    var onTagTap: ((String) -> Void)?
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
                    if let tag = model.pipelineTag,
                       let label = store.pipelineTags.first(where: { $0.id == tag })?.label {
                        Button(label) {
                            onTagTap?(tag)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
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
                if let bytes = store.downloadedSizes[modelID] {
                    Text(bytes.formatted(.byteCount(style: .file)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
