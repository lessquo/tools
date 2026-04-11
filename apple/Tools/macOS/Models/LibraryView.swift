import HuggingFace
import SwiftUI

struct LibraryView: View {
    @Environment(ModelStore.self) private var store
    @State private var selection: HuggingFace.Model.ID?
    @State private var errorMessage: String?

    var allTags: [String] {
        Set(store.downloadedModels.compactMap(\.pipelineTag)).sorted()
    }

    var filteredModels: [HuggingFace.Model] {
        let base = store.libraryFilterTags.isEmpty
            ? store.downloadedModels
            : store.downloadedModels.filter {
                guard let tag = $0.pipelineTag else { return false }
                return store.libraryFilterTags.contains(tag)
            }
        return base.sorted(by: store.librarySortOption)
    }

    var body: some View {
        @Bindable var store = store
        Group {
            if store.downloadedModels.isEmpty {
                ContentUnavailableView(
                    "No Models",
                    systemImage: "square.and.arrow.down",
                    description: Text("Download models from the Explore tab")
                )
            } else {
                List(selection: $selection) {
                    HStack {
                        if allTags.count >= 2 {
                            TagBar(tags: allTags, selection: $store.libraryFilterTags)
                        }
                        Spacer()
                        Picker("Sort by", selection: $store.librarySortOption) {
                            ForEach(ModelStore.SortOption.allCases, id: \.self) {
                                Text($0.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    .listRowSeparator(.hidden)
                    ForEach(filteredModels, id: \.id) { model in
                        ModelRow(model: model, errorMessage: $errorMessage)
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
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
