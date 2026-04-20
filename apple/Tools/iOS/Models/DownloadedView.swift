import HuggingFace
import SwiftUI

@Observable
@MainActor
final class DownloadedViewState {
    var searchText = ""
    var filterTag = ""
    var sortOption: HFService.SortOption = .downloads
    var selection: HuggingFace.Model.ID?
}

struct DownloadedView: View {
    @Environment(HFService.self) private var hfService
    @Environment(DownloadedViewState.self) private var state

    var downloadedTags: [PipelineTag] {
        let ids = Set(hfService.downloadedModels.compactMap(\.pipelineTag))
        return hfService.pipelineTags.filter { ids.contains($0.id) }
    }

    var filteredModels: [HuggingFace.Model] {
        var base = state.filterTag.isEmpty
            ? hfService.downloadedModels
            : hfService.downloadedModels.filter { $0.pipelineTag == state.filterTag }
        if !state.searchText.isEmpty {
            base = base.filter { $0.id.rawValue.localizedCaseInsensitiveContains(state.searchText) }
        }
        return base.sorted(by: state.sortOption)
    }

    var body: some View {
        @Bindable var state = state
        Group {
            if hfService.downloadedModels.isEmpty {
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
                                Text("All Tasks").tag("")
                                ForEach(downloadedTags) { entry in
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
                            ForEach(HFService.SortOption.allCases, id: \.self) {
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
        .alert("Something went wrong", isPresented: Binding(
            get: { hfService.downloadError != nil },
            set: { if !$0 { hfService.downloadError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(hfService.downloadError ?? "")
        }
    }
}
