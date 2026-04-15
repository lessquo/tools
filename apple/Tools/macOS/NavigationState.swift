import Foundation

@Observable
@MainActor
final class NavigationState {
    var sidebarItem: SidebarItem = .quickstart
}
