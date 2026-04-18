import SwiftUI

@main
struct ToolsApp: App {
    @State private var modelStore = ModelStore()
    @State private var apiKeyStore = APIKeyStore()
    @State private var modelsState = ModelsViewState()
    @State private var libraryState = LibraryViewState()
    @State private var exploreState = ExploreViewState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(modelStore)
                .environment(apiKeyStore)
                .environment(modelsState)
                .environment(libraryState)
                .environment(exploreState)
        }
    }
}
