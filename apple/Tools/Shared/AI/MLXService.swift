#if os(macOS)
import Foundation
import MLXLLM
import MLXLMCommon

@Observable
@MainActor
final class MLXService {

    enum State: Equatable {
        case idle
        case loading
        case ready
        case generating
        case error(String)
    }

    private(set) var state: State = .idle
    private var container: ModelContainer?
    private var loadedModelID: String?

    func loadModel(id: String, directory: URL) async throws {
        if loadedModelID == id, container != nil { return }
        state = .loading
        do {
            container = try await LLMModelFactory.shared.loadContainer(
                configuration: ModelConfiguration(directory: directory)
            )
            loadedModelID = id
            state = .ready
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }

    func generate(prompt: String) async throws -> String {
        guard let container else {
            throw MLXServiceError.modelNotLoaded
        }
        state = .generating
        defer { state = .ready }

        let session = ChatSession(
            container,
            generateParameters: GenerateParameters(temperature: 0.0)
        )
        return try await session.respond(to: prompt)
    }
}

enum MLXServiceError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model loaded. Please download and select a model first."
        }
    }
}
#endif
