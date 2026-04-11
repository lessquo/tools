import HuggingFace
import SwiftUI

struct LibraryView: View {
    @Environment(ModelStore.self) private var store
    @State private var errorMessage: String?

    var allTags: [String] {
        Set(store.downloadedModels.compactMap(\.pipelineTag)).sorted()
    }

    var filteredModels: [HuggingFace.Model] {
        guard !store.libraryFilterTags.isEmpty else { return store.downloadedModels }
        return store.downloadedModels.filter {
            guard let tag = $0.pipelineTag else { return false }
            return store.libraryFilterTags.contains(tag)
        }
    }

    var body: some View {
        @Bindable var store = store
        List {
            if allTags.count >= 2 {
                TagBar(tags: allTags, selection: $store.libraryFilterTags)
                    .listRowSeparator(.hidden)
            }
            ForEach(filteredModels, id: \.id) { model in
                ModelRow(model: model, errorMessage: $errorMessage)
            }
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
