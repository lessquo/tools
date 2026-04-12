import HuggingFace
import SwiftUI

struct LibraryView: View {
    @Environment(ModelStore.self) private var store
    @Environment(LibraryViewState.self) private var state

    var downloadedTags: [PipelineTag] {
        let ids = Set(store.downloadedModels.compactMap(\.pipelineTag))
        return store.pipelineTags.filter { ids.contains($0.id) }
    }

    var filteredModels: [HuggingFace.Model] {
        var base = state.filterTag.isEmpty
            ? store.downloadedModels
            : store.downloadedModels.filter { $0.pipelineTag == state.filterTag }
        if !state.searchText.isEmpty {
            base = base.filter { $0.id.rawValue.localizedCaseInsensitiveContains(state.searchText) }
        }
        return base.sorted(by: state.sortOption)
    }

    var body: some View {
        @Bindable var state = state
        Group {
            if store.downloadedModels.isEmpty {
                ContentUnavailableView(
                    "No Models",
                    systemImage: "square.and.arrow.down",
                    description: Text("Download models from the Explore tab")
                )
            } else {
                List {
                    HStack {
                        if downloadedTags.count >= 2 {
                            Picker("Task", selection: $state.filterTag) {
                                Text("All").tag("")
                                ForEach(downloadedTags) { entry in
                                    Text(entry.label).tag(entry.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .fixedSize()
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
                        ModelRow(model: model, onTagTap: { state.filterTag = $0 })
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
