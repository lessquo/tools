import SwiftUI

struct ModelsView: View {
    var body: some View {
        VStack {
            Text("Models")
                .font(.title2)
            Text("Browse, download, and manage local MLX models.")
                .foregroundStyle(.secondary)
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

#Preview {
    ModelsView()
}
