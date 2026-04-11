import HuggingFace
import SwiftUI

struct ExploreView: View {
    @Environment(ModelStore.self) private var store
    @State private var selection: HuggingFace.Model.ID?

    var allTags: [String] {
        Set(store.models.compactMap(\.pipelineTag)).sorted()
    }

    var filteredModels: [HuggingFace.Model] {
        let base = store.exploreFilterTags.isEmpty
            ? store.models
            : store.models.filter {
                guard let tag = $0.pipelineTag else { return false }
                return store.exploreFilterTags.contains(tag)
            }
        return base.sorted(by: store.exploreSortOption)
    }

    var body: some View {
        @Bindable var store = store
        Group {
            if store.models.isEmpty {
                ContentUnavailableView(
                    "No Models",
                    systemImage: "square.grid.2x2",
                    description: Text("Models will appear here")
                )
            } else {
                List(selection: $selection) {
                    HStack {
                        if allTags.count >= 2 {
                            TagBar(tags: allTags, selection: $store.exploreFilterTags)
                        }
                        Spacer()
                        Picker("Sort by", selection: $store.exploreSortOption) {
                            ForEach(ModelStore.SortOption.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    .listRowSeparator(.hidden)
                    ForEach(filteredModels, id: \.id) { model in
                        ModelRow(model: model)
                    }
                }
                .overlay {
                    if filteredModels.isEmpty {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "magnifyingglass",
                            description: Text("Try adjusting your filters")
                        )
                    }
                }
            }
        }
        .alert("Download Failed", isPresented: Binding(
            get: { store.downloadError != nil },
            set: { if !$0 { store.downloadError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.downloadError ?? "")
        }
    }
}
