import SwiftUI

struct ActionsView: View {
    @Environment(ActionStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Group {
            switch store.selectedTab {
            case .myActions: MyActionsView()
            case .templates: ActionTemplatesView()
            }
        }
        .navigationTitle("Actions")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $store.selectedTab) {
                    ForEach(ActionsTab.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }
}

#Preview {
    ActionsView()
        .environment(ActionStore())
}
