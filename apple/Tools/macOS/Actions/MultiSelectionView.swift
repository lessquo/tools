import SwiftUI

struct MultiSelectionView: View {
    let actions: [Action]
    let buttonLabel: String
    let buttonIcon: String
    var buttonRole: ButtonRole?
    var buttonStyle: MultiSelectionButtonStyle = .default
    let action: () -> Void

    init(
        actions: [Action],
        buttonLabel: String,
        buttonIcon: String,
        buttonRole: ButtonRole? = nil,
        buttonStyle: MultiSelectionButtonStyle = .default,
        action: @escaping () -> Void
    ) {
        self.actions = actions
        self.buttonLabel = buttonLabel
        self.buttonIcon = buttonIcon
        self.buttonRole = buttonRole
        self.buttonStyle = buttonStyle
        self.action = action
    }

    enum MultiSelectionButtonStyle {
        case `default`
        case borderedProminent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(actions.count) selected")
                    .font(.title3.bold())
                Spacer()
                actionButton
            }

            List {
                ForEach(actions) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name.isEmpty ? "Untitled" : item.name)
                            .fontWeight(.medium)
                        Text(Self.subtitle(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
    }

    private static func subtitle(for action: Action) -> String {
        "\(action.steps.count) step\(action.steps.count == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var actionButton: some View {
        switch buttonStyle {
        case .borderedProminent:
            Button(role: buttonRole) { action() } label: {
                Label(buttonLabel, systemImage: buttonIcon)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        case .default:
            Button(role: buttonRole) { action() } label: {
                Label(buttonLabel, systemImage: buttonIcon)
            }
            .controlSize(.small)
        }
    }
}
