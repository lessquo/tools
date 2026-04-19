import Foundation

@MainActor
protocol Transcriber {
    func transcribe(pcm: [Float], sampleRate: Double) async throws -> String
}
