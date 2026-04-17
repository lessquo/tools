import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Text("General settings will go here.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 450, height: 300)
    }
}

#Preview {
    SettingsView()
}
