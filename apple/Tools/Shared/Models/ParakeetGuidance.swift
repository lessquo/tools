import SwiftUI

struct ParakeetGuidance: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Which Parakeet?", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
            row(
                name: "parakeet-tdt-0.6b-v2",
                detail: "English. Best accuracy, punctuation, word timestamps."
            )
            row(
                name: "parakeet-tdt-0.6b-v3",
                detail: "25 European languages with auto-detect."
            )
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func row(name: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name).font(.caption.monospaced())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    static func matches(_ searchText: String) -> Bool {
        searchText.localizedCaseInsensitiveContains("parakeet")
    }
}
