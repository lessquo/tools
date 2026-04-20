import AVFAudio
import Foundation
import Speech

@Observable
@MainActor
final class AppleSpeechService: STTService.Backend, ModelService.Provider {

    static let modelID = "apple:speech"

    private(set) var isInstalled: Bool = false
    private var preparedLocale: Locale?

    func modelName(id: String) -> String? {
        id == Self.modelID ? "Apple Speech" : nil
    }

    func refresh() async {
        isInstalled = await Self.isLocaleInstalled()
    }

    func prepare(preferredLocale: Locale = .current) async throws {
        if preparedLocale != nil { return }

        try await Self.requestAuthorization()

        let supported = await SpeechTranscriber.supportedLocales
        let resolved = Self.bestLocale(for: preferredLocale, supported: supported)
            ?? Locale(identifier: "en_US")

        let installed = await SpeechTranscriber.installedLocales
        if !installed.contains(where: { $0.identifier == resolved.identifier }) {
            try await Self.downloadAsset(for: resolved)
        }

        preparedLocale = resolved
        isInstalled = true
    }

    func transcribe(pcm: [Float], sampleRate: Double) async throws -> String {
        guard !pcm.isEmpty else { return "" }
        try await prepare()
        guard let locale = preparedLocale else { throw AppleSpeechError.assetUnavailable }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()

        let collector = Task { () throws -> String in
            var text = ""
            for try await result in transcriber.results where result.isFinal {
                text += String(result.text.characters)
            }
            return text
        }

        try await analyzer.start(inputSequence: stream)

        guard let buffer = Self.makeBuffer(pcm: pcm, sampleRate: sampleRate) else {
            continuation.finish()
            _ = try? await collector.value
            throw AppleSpeechError.bufferAllocationFailed
        }
        continuation.yield(AnalyzerInput(buffer: buffer))
        continuation.finish()

        try await analyzer.finalizeAndFinishThroughEndOfInput()
        return try await collector.value
    }

    // MARK: - Helpers

    private static func requestAuthorization() async throws {
        let status = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        switch status {
        case .authorized: return
        case .denied, .restricted: throw AppleSpeechError.authorizationDenied
        case .notDetermined: throw AppleSpeechError.authorizationDenied
        @unknown default: throw AppleSpeechError.authorizationDenied
        }
    }

    private static func downloadAsset(for locale: Locale) async throws {
        let probe = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) else {
            throw AppleSpeechError.assetUnavailable
        }
        try await request.downloadAndInstall()
    }

    private static func bestLocale(for preferred: Locale, supported: [Locale]) -> Locale? {
        if let exact = supported.first(where: { $0.identifier == preferred.identifier }) {
            return exact
        }
        let language = preferred.language.languageCode?.identifier
        return supported.first { $0.language.languageCode?.identifier == language }
    }

    private static func makeBuffer(pcm: [Float], sampleRate: Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { return nil }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(pcm.count)
        ) else { return nil }

        buffer.frameLength = AVAudioFrameCount(pcm.count)
        guard let channel = buffer.int16ChannelData?[0] else { return nil }
        for i in 0..<pcm.count {
            let clamped = max(-1.0, min(1.0, pcm[i]))
            channel[i] = Int16(clamped * 32767.0)
        }
        return buffer
    }

    private static func isLocaleInstalled(_ locale: Locale = .current) async -> Bool {
        let installed = await SpeechTranscriber.installedLocales
        if installed.contains(where: { $0.identifier == locale.identifier }) { return true }
        let lang = locale.language.languageCode?.identifier
        return installed.contains { $0.language.languageCode?.identifier == lang }
    }
}

enum AppleSpeechError: LocalizedError {
    case authorizationDenied
    case assetUnavailable
    case bufferAllocationFailed

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Speech recognition permission was denied. Enable it in System Settings › Privacy & Security › Speech Recognition."
        case .assetUnavailable:
            return "The speech model for this language is not available on this device."
        case .bufferAllocationFailed:
            return "Failed to allocate an audio buffer for transcription."
        }
    }
}
