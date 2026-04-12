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
    case actions = "Actions"
    case models = "Models"
    case shortcuts = "Shortcuts"

    var systemImage: String {
        switch self {
        case .actions: "bolt"
        case .models: "cube"
        case .shortcuts: "command"
        }
    }
}

struct MainView: View {
    @Environment(NavigationState.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        NavigationSplitView {
            List(SidebarItem.allCases, id: \.self, selection: $navigation.sidebarItem) { item in
                Label(item.rawValue, systemImage: item.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 140, ideal: 160, max: 200)
        } detail: {
            switch navigation.sidebarItem {
            case .actions:
                ActionsView()
            case .models:
                ModelsView()
            case .shortcuts:
                ShortcutsView()
            }
        }
    }
}
