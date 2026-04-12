import Foundation

@Observable
@MainActor
final class LibraryViewState {
    var searchText = ""
    var filterTags: Set<String> = []
    var sortOption: ModelStore.SortOption = .downloads
}
