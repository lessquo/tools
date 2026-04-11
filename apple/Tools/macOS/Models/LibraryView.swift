import HuggingFace
import SwiftUI

struct LibraryView: View {
    @Environment(ModelStore.self) private var store
    @State private var errorMessage: String?

    private var models: [HuggingFace.Model] {
        store.models.filter {
            store.downloadStates[$0.id.rawValue] != .notDownloaded
                && store.downloadStates[$0.id.rawValue] != nil
        }
    }

    var body: some View {
        List(models, id: \.id) { model in
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
