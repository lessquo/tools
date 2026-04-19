import AVFAudio
import Foundation

@Observable
@MainActor
final class AudioCaptureService {

    enum State: Equatable {
        case idle
        case recording
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var level: Float = 0  // 0...1 normalized RMS for meter UI

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private var buffer: [Float] = []
    private let targetSampleRate: Double = 16_000
    var sampleRate: Double { targetSampleRate }

    func start() async throws {
        if case .recording = state { return }

        guard await requestPermission() else {
            state = .error("Microphone access denied")
            throw AudioCaptureError.permissionDenied
        }

        buffer.removeAll(keepingCapacity: true)
        level = 0

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            state = .error("Unsupported audio format")
            throw AudioCaptureError.formatUnavailable
        }
        targetFormat = target
        converter = AVAudioConverter(from: inputFormat, to: target)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] pcm, _ in
            self?.handleTap(pcm)
        }

        do {
            engine.prepare()
            try engine.start()
            state = .recording
        } catch {
            input.removeTap(onBus: 0)
            state = .error(error.localizedDescription)
            throw error
        }
    }

    func stop() -> [Float] {
        guard case .recording = state else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        state = .idle
        level = 0
        let captured = buffer
        buffer.removeAll(keepingCapacity: false)
        return captured
    }

    // MARK: - Private

    private nonisolated func handleTap(_ pcm: AVAudioPCMBuffer) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.convertAndAppend(pcm)
        }
    }

    private func convertAndAppend(_ pcm: AVAudioPCMBuffer) {
        guard let converter, let targetFormat else { return }

        let ratio = targetFormat.sampleRate / pcm.format.sampleRate
        let capacity = AVAudioFrameCount(Double(pcm.frameLength) * ratio + 1024)
        guard let output = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: capacity
        ) else { return }

        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return pcm
        }
        if error != nil { return }

        guard let channel = output.floatChannelData?[0] else { return }
        let frames = Int(output.frameLength)
        guard frames > 0 else { return }

        var samples = [Float](repeating: 0, count: frames)
        samples.withUnsafeMutableBufferPointer { dst in
            dst.baseAddress?.update(from: channel, count: frames)
        }

        // RMS for level meter
        var sumSquares: Float = 0
        for sample in samples { sumSquares += sample * sample }
        let rms = sqrt(sumSquares / Float(frames))
        // Perceptual curve: sqrt boosts small values so quiet speech visibly moves the meter.
        level = sqrt(min(1, rms * 8))

        buffer.append(contentsOf: samples)
    }

    private func requestPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        @unknown default: return false
        }
    }
}

enum AudioCaptureError: LocalizedError {
    case permissionDenied
    case formatUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Microphone access denied"
        case .formatUnavailable: "Could not configure audio format"
        }
    }
}
