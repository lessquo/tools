import SwiftUI

struct ExploreView: View {
    @Environment(ModelStore.self) private var store
    @State private var errorMessage: String?

    var body: some View {
        List(store.models, id: \.id) { model in
            ModelRow(model: model, errorMessage: $errorMessage)
        }
        .alert("Download Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
