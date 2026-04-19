import SwiftUI

struct QuickstartCard<Rows: View>: View {
    let title: String
    let description: String
    let systemImage: String
    let shortcut: String
    @Binding var isEnabled: Bool
    @ViewBuilder let rows: () -> Rows

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 28, height: 28)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.title2).bold()
                    Text(shortcut)
                        .font(.caption)
                        .monospaced()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    rows()
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(16)
        .cardBackground()
    }
}

struct Requirement: Identifiable {
    let id: String
    let label: String
    var detail: String? = nil
    let isReady: Bool
    let actionLabel: String
    var readyActionLabel: String? = nil
    let action: () -> Void
    var readyAction: (() -> Void)? = nil
}

struct RequirementRow: View {
    let requirement: Requirement

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: requirement.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(requirement.isReady ? .green : .orange)
                .font(.footnote)
            VStack(alignment: .leading, spacing: 2) {
                Text(requirement.label)
                    .font(.callout)
                if let detail = requirement.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if !requirement.isReady {
                Button(requirement.actionLabel, action: requirement.action)
                    .controlSize(.small)
            } else if let readyLabel = requirement.readyActionLabel {
                Button(readyLabel, action: requirement.readyAction ?? requirement.action)
                    .controlSize(.small)
            }
        }
    }
}

struct ModelPickerRow: View {
    @Environment(ModelStore.self) private var store

    let feature: ModelStore.Feature
    @Binding var selectedID: String
    let label: String
    var browseMoreLabel: String = "Browse more…"
    let openExplore: () -> Void

    var body: some View {
        let downloaded = store.downloadedModels(for: feature)
        let isReady = store.isModelDownloaded(id: selectedID)
        let showApple = feature == .dictation

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isReady ? .green : .orange)
                .font(.footnote)
            Text(label)
                .font(.callout)
            Spacer(minLength: 8)

            if !showApple && downloaded.isEmpty {
                Button("Install") { openExplore() }
                    .controlSize(.small)
            } else {
                Menu {
                    if showApple {
                        Button {
                            selectedID = STTService.appleSpeechID
                        } label: {
                            if selectedID == STTService.appleSpeechID {
                                Label("Apple Speech", systemImage: "checkmark")
                            } else {
                                Text("Apple Speech")
                            }
                        }
                        if !downloaded.isEmpty { Divider() }
                    }
                    ForEach(downloaded, id: \.id) { model in
                        Button {
                            selectedID = model.id.rawValue
                        } label: {
                            if model.id.rawValue == selectedID {
                                Label(model.id.name, systemImage: "checkmark")
                            } else {
                                Text(model.id.name)
                            }
                        }
                    }
                    Divider()
                    Button(browseMoreLabel) { openExplore() }
                } label: {
                    Text(store.displayName(id: selectedID))
                }
                .fixedSize()
                .controlSize(.small)
            }
        }
    }
}

private extension View {
    func cardBackground() -> some View {
        background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator)
            )
    }
}
