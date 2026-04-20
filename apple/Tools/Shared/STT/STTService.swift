import Foundation

@Observable
@MainActor
final class STTService {

    @MainActor
    protocol Backend {
        func transcribe(pcm: [Float], sampleRate: Double) async throws -> String
    }

    enum State: Equatable {
        case idle
        case loading
        case ready
        case transcribing
        case error(String)
    }

    private(set) var state: State = .idle
    private var backend: (any Backend)?
    private var loadedModelID: String?
    private let hfService: HFService
    private let appleSpeechService: AppleSpeechService

    init(hfService: HFService, appleSpeechService: AppleSpeechService) {
        self.hfService = hfService
        self.appleSpeechService = appleSpeechService
    }

    func loadModel(id: String) async throws {
        if loadedModelID == id, backend != nil { return }
        state = .loading
        do {
            backend = try await makeBackend(id: id)
            loadedModelID = id
            state = .ready
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    func transcribe(pcm: [Float], sampleRate: Double) async throws -> String {
        guard let backend else { throw STTServiceError.modelNotLoaded }
        guard !pcm.isEmpty else { return "" }

        state = .transcribing
        defer { state = .ready }

        return try await backend.transcribe(pcm: pcm, sampleRate: sampleRate)
    }

    private func makeBackend(id: String) async throws -> any Backend {
        if id == AppleSpeechService.modelID {
            try await appleSpeechService.prepare()
            return appleSpeechService
        }
        return try ParakeetService(directory: hfService.modelDirectory(for: id))
    }
}

enum STTServiceError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No speech model loaded. Pick Apple Speech or download a Parakeet model first."
        }
    }
}
