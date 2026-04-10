import SwiftUI

extension Text {
    func badgeStyle() -> some View {
        self
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
