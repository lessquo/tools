import SwiftUI

struct ActionTemplatesView: View {
    var body: some View {
        ContentUnavailableView(
            "Coming Soon",
            systemImage: "square.grid.2x2",
            description: Text("Browse pre-made action templates")
        )
    }
}
