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

    private let variations: [CGFloat] = [0.7, 1.0, 0.85, 0.6]
    private let minHeight: CGFloat = 3
    private let maxHeight: CGFloat = 18

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<variations.count, id: \.self) { i in
                Capsule()
                    .fill(.tint)
                    .frame(width: 3, height: height(for: i))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }

    private func height(for index: Int) -> CGFloat {
        let amplitude = min(CGFloat(level), 1)
        return minHeight + amplitude * variations[index] * (maxHeight - minHeight)
    }
}
