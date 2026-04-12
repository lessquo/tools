import HuggingFace
import SwiftUI

struct ExploreView: View {
    @Environment(ModelStore.self) private var store
    @Environment(ExploreViewState.self) private var state

    var filteredModels: [HuggingFace.Model] {
        var base = state.filterTag.isEmpty
            ? store.models
            : store.models.filter { $0.pipelineTag == state.filterTag }
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
                List {
                    HStack {
                        if store.pipelineTags.count >= 2 {
                            Picker("Task", selection: $state.filterTag) {
                                Text("All Tasks").tag("")
                                ForEach(store.pipelineTags) { entry in
                                    Text(entry.label).tag(entry.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            if !state.filterTag.isEmpty {
                                Button {
                                    state.filterTag = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Picker(selection: $state.sortOption) {
                            ForEach(ModelStore.SortOption.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .pickerStyle(.menu)
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
