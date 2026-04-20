import HuggingFace
import SwiftUI

struct ModelRow: View {
    @Environment(HFService.self) private var hfService
    let model: HuggingFace.Model
    var onTagTap: ((String) -> Void)?
    var body: some View {
        let modelID = model.id.rawValue
        let state = hfService.downloadStates[modelID] ?? .notDownloaded

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
                       let label = hfService.pipelineTags.first(where: { $0.id == tag })?.label {
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

            switch state {
            case .notDownloaded:
                Button {
                    hfService.startDownload(model)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)

            case .downloading(let fraction):
                ProgressView(value: fraction)
                    .frame(width: 60)
                Button {
                    hfService.cancelDownload(model)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)

            case .downloaded:
                if let bytes = hfService.downloadedSizes[modelID] {
                    Text(bytes.formatted(.byteCount(style: .file)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy Name") {
                UIPasteboard.general.string = modelID
            }
        }
    }
}
