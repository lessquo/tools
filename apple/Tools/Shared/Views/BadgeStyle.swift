import SwiftUI

extension Text {
    func badgeStyle(selected: Bool = false) -> some View {
        self
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .background(selected ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.quaternary))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
