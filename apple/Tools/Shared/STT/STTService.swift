import Foundation
import MLX
import MLXAudioSTT

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

    private enum Backend {
        case apple(AppleSpeechTranscriber)
        case parakeet(ParakeetModel)
    }

    private(set) var state: State = .idle
    private var backend: Backend?
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

        switch backend {
        case .apple(let transcriber):
            return try await transcriber.transcribe(pcm: pcm, sampleRate: sampleRate)
        case .parakeet(let model):
            let audio = MLXArray(pcm)
            return model.generate(audio: audio).text
        }
    }

    private static func makeBackend(id: String, directory: URL?) async throws -> Backend {
        if id == appleSpeechID {
            let transcriber = AppleSpeechTranscriber()
            try await transcriber.prepare()
            return .apple(transcriber)
        }

        guard let directory else { throw STTServiceError.modelNotLoaded }
        let model = try ParakeetModel.fromDirectory(directory)
        return .parakeet(model)
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
