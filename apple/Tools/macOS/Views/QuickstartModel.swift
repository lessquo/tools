import SwiftUI

struct QuickstartModelOption: Identifiable, Hashable {
    let id: String
    let name: String
}

struct QuickstartModel: View {
    @Binding var selectedID: String
    let label: String
    let displayName: String
    let isReady: Bool
    let primaryOption: QuickstartModelOption?
    let options: [QuickstartModelOption]
    var browseMoreLabel: String = "Browse more…"
    let openExplore: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isReady ? .green : .orange)
                .font(.footnote)
            Text(label)
                .font(.callout)
            Spacer(minLength: 8)

            if primaryOption == nil && options.isEmpty {
                Button("Install") { openExplore() }
                    .controlSize(.small)
            } else {
                Menu {
                    if let primary = primaryOption {
                        optionButton(primary)
                        if !options.isEmpty { Divider() }
                    }
                    ForEach(options) { optionButton($0) }
                    Divider()
                    Button(browseMoreLabel) { openExplore() }
                } label: {
                    Text(displayName)
                }
                .fixedSize()
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func optionButton(_ option: QuickstartModelOption) -> some View {
        Button {
            selectedID = option.id
        } label: {
            if option.id == selectedID {
                Label(option.name, systemImage: "checkmark")
            } else {
                Text(option.name)
            }
        }
    }
}
