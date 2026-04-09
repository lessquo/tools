import SwiftUI

struct APIKeysView: View {
    var body: some View {
        Form {
            Text("API key management will go here.")
                .foregroundStyle(.secondary)
            Text("Keys are stored in Keychain.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

#Preview {
    APIKeysView()
}
