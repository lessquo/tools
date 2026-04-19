import SwiftUI

struct ShortcutRow: View {
    let title: String
    let keys: String

    init(_ title: String, keys: String) {
        self.title = title
        self.keys = keys
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(keys)
                .foregroundStyle(.secondary)
                .monospaced()
        }
    }
}

struct ShortcutsView: View {
    @Environment(DictationService.self) private var dictationService
    @Environment(QuickActionsService.self) private var quickActionsService

    var body: some View {
        List {
            Section("Global") {
                ShortcutRow("Hold to Dictate", keys: dictationService.shortcut.display)
                ShortcutRow("Activate Quick Actions", keys: quickActionsService.shortcut.display)
            }
            Section("Navigation") {
                ShortcutRow("Previous Sidebar Item", keys: "⌥⌘ ↑")
                ShortcutRow("Next Sidebar Item", keys: "⌥⌘ ↓")
                ShortcutRow("Previous Tab", keys: "⌥⌘ ←")
                ShortcutRow("Next Tab", keys: "⌥⌘ →")
            }
            Section("Quick Actions") {
                ShortcutRow("Dismiss", keys: "⎋")
                ShortcutRow("Select Action by Number", keys: "1 – 9")
                ShortcutRow("Navigate Up", keys: "↑")
                ShortcutRow("Navigate Down", keys: "↓")
                ShortcutRow("Trigger Selected Action", keys: "↩")
                ShortcutRow("Apply Result", keys: "⌘ ↩")
            }
            Section("Actions") {
                ShortcutRow("New Action", keys: "⌘ N")
            }
        }
        .navigationTitle("Shortcuts")
    }
}
