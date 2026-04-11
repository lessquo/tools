import HuggingFace
import SwiftUI

struct ExploreView: View {
    @Environment(ModelStore.self) private var store
    @State private var errorMessage: String?

    var allTags: [String] {
        Set(store.models.compactMap(\.pipelineTag)).sorted()
    }

    var filteredModels: [HuggingFace.Model] {
        guard !store.exploreFilterTags.isEmpty else { return store.models }
        return store.models.filter {
            guard let tag = $0.pipelineTag else { return false }
            return store.exploreFilterTags.contains(tag)
        }
    }

    var body: some View {
        @Bindable var store = store
        List {
            if allTags.count >= 2 {
                TagBar(tags: allTags, selection: $store.exploreFilterTags)
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
