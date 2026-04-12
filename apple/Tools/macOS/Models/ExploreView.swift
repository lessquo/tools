import HuggingFace
import SwiftUI

struct ExploreView: View {
    @Environment(ModelStore.self) private var store
    @Environment(ExploreViewState.self) private var state
    @State private var selection: HuggingFace.Model.ID?

    var allTags: [String] {
        Set(store.models.compactMap(\.pipelineTag)).sorted()
    }

    var filteredModels: [HuggingFace.Model] {
        var base = state.filterTags.isEmpty
            ? store.models
            : store.models.filter {
                guard let tag = $0.pipelineTag else { return false }
                return state.filterTags.contains(tag)
            }
        if !state.searchText.isEmpty {
            base = base.filter { $0.id.rawValue.localizedCaseInsensitiveContains(state.searchText) }
        }
        return base.sorted(by: state.sortOption)
    }

    var body: some View {
        @Bindable var state = state
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
                            TagBar(tags: allTags, selection: $state.filterTags)
                        }
                        Spacer()
                        Picker("Sort by", selection: $state.sortOption) {
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
                            description: Text("Try adjusting your search or filters")
                        )
                    }
                }
            }
        }
        .searchable(text: $state.searchText)
        .onChange(of: state.sortOption) {
            Task { await store.fetchModels(sort: state.sortOption) }
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
