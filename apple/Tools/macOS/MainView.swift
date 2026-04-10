import SwiftUI

enum SidebarItem: String, CaseIterable {
    case actions = "Actions"
    case models = "Models"

    var systemImage: String {
        switch self {
        case .actions: "bolt"
        case .models: "cube"
        }
    }
}

struct MainView: View {
    @State private var selection: SidebarItem = .actions

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, id: \.self, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 140, ideal: 160, max: 200)
        } detail: {
            switch selection {
            case .actions:
                ActionsView()
            case .models:
                ModelsView()
            }
        }
    }
}
