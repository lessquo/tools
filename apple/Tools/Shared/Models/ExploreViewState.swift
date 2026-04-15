import Foundation
import HuggingFace

@Observable
@MainActor
final class ExploreViewState {
    var searchText = ""
    var filterTag = ""
    var sortOption: ModelStore.SortOption = .downloads
    var selection: HuggingFace.Model.ID?
}
