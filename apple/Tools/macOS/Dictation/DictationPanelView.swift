import SwiftUI

struct DictationPanelView: View {

    @Bindable var audio: AudioCaptureService
    @Bindable var stt: STTService

    var body: some View {
        HStack(spacing: 12) {
            leadingIndicator
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var isTranscribing: Bool {
        stt.state == .transcribing
    }

    private var label: String {
        isTranscribing ? "Transcribing…" : "Listening…"
    }

    @ViewBuilder
    private var leadingIndicator: some View {
        if isTranscribing {
            ProgressView()
                .controlSize(.small)
                .frame(width: 28, height: 28)
        } else {
            Waveform(level: audio.level)
                .frame(width: 28, height: 28)
        }
    }
}

private struct Waveform: View {
    let level: Float

    private let barCount = 4
    private let weights: [Float] = [0.6, 1.0, 0.8, 0.5]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(.tint)
                    .frame(width: 3, height: height(for: i))
                    .animation(.easeOut(duration: 0.12), value: level)
            }
        }
    }

    private func height(for index: Int) -> CGFloat {
        let normalized = max(0.08, CGFloat(level * weights[index]))
        return max(4, min(26, normalized * 26))
    }
}
