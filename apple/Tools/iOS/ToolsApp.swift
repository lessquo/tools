import SwiftUI

@main
struct ToolsApp: App {
    @State private var hfService: HFService
    @State private var appleSpeechService: AppleSpeechService
    @State private var modelService: ModelService
    @State private var apiKeyStore = APIKeyStore()
    @State private var modelsState = ModelsViewState()
    @State private var downloadedState = DownloadedViewState()
    @State private var exploreState = ExploreViewState()

    init() {
        let hf = HFService()
        let apple = AppleSpeechService()
        _hfService = State(initialValue: hf)
        _appleSpeechService = State(initialValue: apple)
        _modelService = State(initialValue: ModelService(hfService: hf, appleSpeechService: apple))
        Task { await apple.refresh() }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(hfService)
                .environment(modelService)
                .environment(apiKeyStore)
                .environment(modelsState)
                .environment(downloadedState)
                .environment(exploreState)
        }
    }
}
