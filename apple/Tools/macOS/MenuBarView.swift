import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 4) {
            Button("Text Action") {
                // TODO: Trigger text action
            }
            .keyboardShortcut("t", modifiers: [.command])

            Divider()

            Button("Models...") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }

            SettingsLink {
                Text("Settings...")
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .padding(4)
    }
}

#Preview {
    MenuBarView()
}
