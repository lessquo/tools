import HuggingFace
import SwiftUI

@Observable
@MainActor
final class ExploreViewState {
    var searchText = ""
    var filterTag = ""
    var sortOption: ModelStore.SortOption = .downloads
    var selection: HuggingFace.Model.ID?
}

struct ExploreView: View {
    @Environment(ModelStore.self) private var store
    @Environment(ExploreViewState.self) private var state

    var filteredModels: [HuggingFace.Model] {
        let base = state.filterTag.isEmpty
            ? store.models
            : store.models.filter { $0.pipelineTag == state.filterTag }
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
                ScrollViewReader { proxy in
                    List(selection: $state.selection) {
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
                                .fixedSize()
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
                    .onAppear {
                        if let id = state.selection {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .searchable(text: $state.searchText)
        .task(id: state.searchText) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await store.fetchModels(search: state.searchText, sort: state.sortOption, pipelineTag: state.filterTag)
        }
        .onChange(of: state.sortOption) {
            Task { await store.fetchModels(search: state.searchText, sort: state.sortOption, pipelineTag: state.filterTag) }
        }
        .onChange(of: state.filterTag) {
            Task { await store.fetchModels(search: state.searchText, sort: state.sortOption, pipelineTag: state.filterTag) }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { store.downloadError != nil },
            set: { if !$0 { store.downloadError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.downloadError ?? "")
        }
    }
}
