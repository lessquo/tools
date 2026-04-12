import Foundation

@Observable
@MainActor
final class ExploreViewState {
    var searchText = ""
    var filterTags: Set<String> = []
    var sortOption: ModelStore.SortOption = .downloads
}
