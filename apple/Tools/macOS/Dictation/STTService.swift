import Foundation
import MLX
import MLXAudioSTT

@Observable
@MainActor
final class STTService {

    enum State: Equatable {
        case idle
        case loading
        case ready
        case transcribing
        case error(String)
    }

    private(set) var state: State = .idle
    private var model: ParakeetModel?
    private var loadedModelID: String?

    func loadModel(id: String, directory: URL) async throws {
        if loadedModelID == id, model != nil { return }
        state = .loading
        do {
            model = try ParakeetModel.fromDirectory(directory)
            loadedModelID = id
            state = .ready
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    func transcribe(pcm: [Float]) async throws -> String {
        guard let model else { throw STTServiceError.modelNotLoaded }
        guard !pcm.isEmpty else { return "" }

        state = .transcribing
        defer { state = .ready }

        let audio = MLXArray(pcm)
        let output = model.generate(audio: audio)
        return output.text
    }
}

enum STTServiceError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No speech model loaded. Download a Parakeet model first."
        }
    }
}
