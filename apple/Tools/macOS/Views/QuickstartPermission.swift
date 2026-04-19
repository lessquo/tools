import SwiftUI

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

struct QuickstartPermission: View {
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
