import SwiftUI

struct DictationPanelView: View {

    @Bindable var audio: AudioCaptureService
    @Bindable var stt: STTService

    var body: some View {
        indicator
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
    }

    @ViewBuilder
    private var indicator: some View {
        if stt.state == .transcribing {
            ProgressView()
                .controlSize(.small)
                .frame(width: 28, height: 20)
        } else {
            Waveform(level: audio.level)
                .frame(width: 28, height: 20)
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
        return max(4, min(18, normalized * 18))
    }
}
