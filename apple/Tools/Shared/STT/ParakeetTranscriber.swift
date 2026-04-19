import Foundation
import MLX
import MLXAudioSTT

@MainActor
final class ParakeetTranscriber: Transcriber {

    private let model: ParakeetModel

    init(directory: URL) throws {
        self.model = try ParakeetModel.fromDirectory(directory)
    }

    func transcribe(pcm: [Float], sampleRate: Double) async throws -> String {
        guard !pcm.isEmpty else { return "" }
        let audio = MLXArray(pcm)
        return model.generate(audio: audio).text
    }
}
