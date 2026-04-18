import SwiftUI

struct QuickActionsView: View {
    @Environment(ModelStore.self) private var modelStore
    @Environment(ModelsViewState.self) private var modelsState
    @Environment(ExploreViewState.self) private var exploreState
    @Environment(MainViewState.self) private var mainViewState
    @Environment(FeaturesState.self) private var featuresState
    @Environment(PermissionsService.self) private var permissions

    var body: some View {
        @Bindable var featuresState = featuresState
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                QuickstartCard(
                    title: "Quick Actions",
                    description: "Press ⌘; to run an action on selected text from any app.",
                    systemImage: "bolt",
                    shortcut: "⌘ ;",
                    isEnabled: $featuresState.quickActionsEnabled
                ) {
                    ModelPickerRow(
                        feature: .quickActions,
                        label: "Text-generation model",
                        openExplore: openExplore
                    )
                    RequirementRow(requirement: .init(
                        id: "accessibility",
                        label: "Accessibility access",
                        detail: "Used to detect ⌘; across apps.",
                        isReady: permissions.isAccessibilityGranted,
                        actionLabel: "Grant",
                        readyActionLabel: "Settings",
                        action: permissions.requestAccessibility,
                        readyAction: permissions.openAccessibilitySettings
                    ))
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .navigationTitle("Quick Actions")
    }

    private func openExplore(filterTag: String) {
        exploreState.filterTag = filterTag
        modelsState.selectedTab = .explore
        mainViewState.sidebarItem = .models
    }
}

#Preview {
    QuickActionsView()
        .environment(FeaturesState())
        .environment(MainViewState())
        .environment(ModelStore())
        .environment(ModelsViewState())
        .environment(ExploreViewState())
        .environment(PermissionsService())
        .frame(width: 800, height: 700)
}
