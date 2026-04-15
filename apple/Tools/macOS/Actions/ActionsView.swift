import SwiftUI

enum ActionsTab: String, CaseIterable {
    case myActions = "My Actions"
    case templates = "Templates"
}

@Observable
@MainActor
final class ActionsViewState {
    var selectedTab = ActionsTab.myActions
}

struct ActionsView: View {
    @Environment(ActionsViewState.self) private var state

    var body: some View {
        @Bindable var state = state
        Group {
            switch state.selectedTab {
            case .myActions: MyActionsView()
            case .templates: TemplatesView()
            }
        }
        .navigationTitle("Actions")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $state.selectedTab) {
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
        .environment(ActionsViewState())
        .environment(MyActionsViewState())
        .environment(TemplatesViewState())
}
