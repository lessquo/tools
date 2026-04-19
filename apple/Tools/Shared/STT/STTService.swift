import Foundation

@Observable
@MainActor
final class STTService {

    static let appleSpeechID = "apple:speech"

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

    func loadModel(id: String, directory: URL?) async throws {
        if loadedModelID == id, backend != nil { return }
        state = .loading
        do {
            backend = try await Self.makeBackend(id: id, directory: directory)
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

    private static func makeBackend(id: String, directory: URL?) async throws -> any Backend {
        if id == appleSpeechID {
            return try await AppleSpeechBackend()
        }

        guard let directory else { throw STTServiceError.modelNotLoaded }
        return try ParakeetBackend(directory: directory)
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
