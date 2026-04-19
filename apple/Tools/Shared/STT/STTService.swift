import Foundation

@Observable
@MainActor
final class STTService {

    static let appleSpeechID = "apple:speech"

    enum State: Equatable {
        case idle
        case loading
        case ready
        case transcribing
        case error(String)
    }

    private(set) var state: State = .idle
    private var transcriber: (any Transcriber)?
    private var loadedModelID: String?

    func loadModel(id: String, directory: URL?) async throws {
        if loadedModelID == id, transcriber != nil { return }
        state = .loading
        do {
            transcriber = try await Self.makeTranscriber(id: id, directory: directory)
            loadedModelID = id
            state = .ready
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    func transcribe(pcm: [Float], sampleRate: Double) async throws -> String {
        guard let transcriber else { throw STTServiceError.modelNotLoaded }
        guard !pcm.isEmpty else { return "" }

        state = .transcribing
        defer { state = .ready }

        return try await transcriber.transcribe(pcm: pcm, sampleRate: sampleRate)
    }

    private static func makeTranscriber(id: String, directory: URL?) async throws -> any Transcriber {
        if id == appleSpeechID {
            let apple = AppleSpeechTranscriber()
            try await apple.prepare()
            return apple
        }

        guard let directory else { throw STTServiceError.modelNotLoaded }
        return try ParakeetTranscriber(directory: directory)
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
