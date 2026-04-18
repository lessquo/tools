import SwiftUI

extension CaseIterable where Self: Equatable {
    var previous: Self {
        let all = Array(Self.allCases)
        let idx = all.firstIndex(of: self)!
        return all[(idx - 1 + all.count) % all.count]
    }

    var next: Self {
        let all = Array(Self.allCases)
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }
}

enum SidebarItem: String, CaseIterable {
    case quickstart = "Quickstart"
    case actions = "Actions"
    case models = "Models"
    case apiKeys = "API Keys"
    case shortcuts = "Shortcuts"

    var systemImage: String {
        switch self {
        case .quickstart: "sparkles"
        case .actions: "bolt"
        case .models: "cube"
        case .apiKeys: "key"
        case .shortcuts: "command"
        }
    }
}

@Observable
@MainActor
final class MainViewState {
    var sidebarItem: SidebarItem = .quickstart
}

struct MainView: View {
    @Environment(MainViewState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            List(SidebarItem.allCases, id: \.self, selection: $state.sidebarItem) { item in
                Label(item.rawValue, systemImage: item.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 140, ideal: 160, max: 200)
        } detail: {
            switch state.sidebarItem {
            case .quickstart:
                QuickstartView()
            case .actions:
                ActionsView()
            case .models:
                ModelsView()
            case .apiKeys:
                APIKeysView()
            case .shortcuts:
                ShortcutsView()
            }
        }
    }
}
