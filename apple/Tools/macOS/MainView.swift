import SwiftUI

enum SidebarItem: String, CaseIterable {
    case models = "Models"
    case textActions = "Text Actions"

    var systemImage: String {
        switch self {
        case .models: "cube"
        case .textActions: "text.bubble"
        }
    }
}

struct MainView: View {
    @State private var selection: SidebarItem = .models

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, id: \.self, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 140, ideal: 160, max: 200)
        } detail: {
            switch selection {
            case .models:
                ModelsView()
            case .textActions:
                TextActionsView()
            }
        }
    }
}
