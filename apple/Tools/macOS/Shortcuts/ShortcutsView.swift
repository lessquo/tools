import SwiftUI

struct ShortcutsView: View {
    var body: some View {
        ContentUnavailableView(
            "No Shortcuts",
            systemImage: "command",
            description: Text("Shortcuts will appear here")
        )
        .navigationTitle("Shortcuts")
    }
}
