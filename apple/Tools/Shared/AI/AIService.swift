#if os(macOS)
import Foundation

@Observable
@MainActor
final class AIService {

    let mlx = MLXService()

    func loadModel(id: String, directory: URL) async throws {
        try await mlx.loadModel(id: id, directory: directory)
    }

    func generate(prompt: String) async throws -> String {
        try await mlx.generate(prompt: prompt)
    }

    func generateStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        mlx.generateStream(prompt: prompt)
    }

    var isProcessing: Bool {
        mlx.state == .generating || mlx.state == .loading
    }
}
#endif
