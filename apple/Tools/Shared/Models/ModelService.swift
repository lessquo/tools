import Foundation

@Observable
@MainActor
final class ModelService {

    @MainActor
    protocol Provider {
        func modelName(id: String) -> String?
    }

    private let hfService: HFService
    private let appleSpeechService: AppleSpeechService

    init(hfService: HFService, appleSpeechService: AppleSpeechService) {
        self.hfService = hfService
        self.appleSpeechService = appleSpeechService
    }

    func isModelReady(id: String) -> Bool {
        if id == AppleSpeechService.modelID { return appleSpeechService.isInstalled }
        return !id.isEmpty && hfService.downloadStates[id] == .downloaded
    }

    func modelName(id: String) -> String {
        appleSpeechService.modelName(id: id)
            ?? hfService.modelName(id: id)
            ?? "Select model"
    }
}
