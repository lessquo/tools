import Foundation

@Observable
@MainActor
final class ModelsViewState {
    var selectedTab = ModelsTab.library
}
