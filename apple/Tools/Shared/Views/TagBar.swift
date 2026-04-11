import SwiftUI

struct TagBar: View {
    let tags: [String]
    @Binding var selection: Set<String>

    var body: some View {
        FlowLayout(spacing: 6) {
            Text("Tags")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(tags, id: \.self) { tag in
                Button {
                    if selection.contains(tag) {
                        selection.remove(tag)
                    } else {
                        selection.insert(tag)
                    }
                } label: {
                    Text(tag).badgeStyle(selected: selection.contains(tag))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + (i > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            if i > 0 { y += spacing }
            var x = bounds.minX
            for index in row {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rowHeight
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var x: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !rows[rows.count - 1].isEmpty && x + size.width > maxWidth {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(index)
            x += size.width + spacing
        }
        return rows
    }
}
