import SwiftUI

@main
struct ToolsApp: App {
    @State private var modelStore = ModelStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(modelStore)
        }
    }
}
