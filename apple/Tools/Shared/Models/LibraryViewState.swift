import Foundation

@Observable
@MainActor
final class LibraryViewState {
    var searchText = ""
    var filterTag = ""
    var sortOption: ModelStore.SortOption = .downloads
}
