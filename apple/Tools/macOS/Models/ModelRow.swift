import AppKit
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
                    Image(systemName: "cube")
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
                        PipelineTagButton(label: label) {
                            onTagTap?(tag)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

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
                Button("Delete", role: .destructive) {
                    do {
                        try store.deleteDownload(model)
                    } catch {
                        store.downloadError = "Could not delete \(model.id.name): \(error.localizedDescription)"
                    }
                }
            }
            Divider()
            Button("Copy Name") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(modelID, forType: .string)
            }
            Link("View on Hugging Face", destination: URL(string: "https://huggingface.co/\(modelID)")!)
        }
    }
}

private struct PipelineTagButton: View {
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(label, action: action)
            .buttonStyle(.plain)
            .foregroundStyle(isHovered ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .onHover { isHovered = $0 }
    }
}
