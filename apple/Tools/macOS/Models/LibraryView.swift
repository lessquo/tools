import HuggingFace
import SwiftUI

@Observable
@MainActor
final class LibraryViewState {
    var searchText = ""
    var filterTag = ""
    var sortOption: HFService.SortOption = .downloads
    var selection: HuggingFace.Model.ID?
}

struct LibraryView: View {
    @Environment(HFService.self) private var store
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
                ScrollViewReader { proxy in
                    List(selection: $state.selection) {
                        HStack {
                            if downloadedTags.count >= 2 {
                                Picker("Task", selection: $state.filterTag) {
                                    Text("All Tasks").tag("")
                                    ForEach(downloadedTags) { entry in
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
                                ForEach(HFService.SortOption.allCases, id: \.self) {
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
        .toolbar {
            ToolbarItem {
                Button {
                    NSWorkspace.shared.open(store.cacheDirectory)
                } label: {
                    Image(systemName: "folder")
                }
                .help("Show in Finder")
            }
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
