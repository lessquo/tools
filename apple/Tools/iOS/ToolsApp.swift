import SwiftUI

@main
struct ToolsApp: App {
    @State private var hfService = HFService()
    @State private var apiKeyStore = APIKeyStore()
    @State private var modelsState = ModelsViewState()
    @State private var libraryState = LibraryViewState()
    @State private var exploreState = ExploreViewState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(hfService)
                .environment(apiKeyStore)
                .environment(modelsState)
                .environment(libraryState)
                .environment(exploreState)
        }
    }
}
