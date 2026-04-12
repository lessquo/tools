import Foundation

@Observable
@MainActor
final class ExploreViewState {
    var searchText = ""
    var filterTag = ""
    var sortOption: ModelStore.SortOption = .downloads
}
