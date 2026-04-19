import SwiftUI

struct QuickActionsView: View {
    @Environment(ModelStore.self) private var modelStore
    @Environment(ModelsViewState.self) private var modelsState
    @Environment(ExploreViewState.self) private var exploreState
    @Environment(MainViewState.self) private var mainViewState
    @Environment(QuickActionsService.self) private var quickActionsService
    @Environment(PermissionsService.self) private var permissions

    var body: some View {
        @Bindable var quickActionsService = quickActionsService
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                QuickstartCard(
                    title: "Quick Actions",
                    description: "Press the shortcut to run an action on selected text from any app.",
                    systemImage: "cursorarrow.rays",
                    shortcut: quickActionsService.shortcut.display,
                    isEnabled: $quickActionsService.isEnabled
                ) {
                    ShortcutSettingRow(
                        shortcut: $quickActionsService.shortcut,
                        lockedMode: .tap,
                        defaultShortcut: .quickActionsDefault
                    )
                    QuickstartModel(
                        selectedID: $quickActionsService.modelID,
                        label: "Text-generation model",
                        displayName: modelStore.displayName(id: quickActionsService.modelID),
                        isReady: modelStore.isModelDownloaded(id: quickActionsService.modelID),
                        primaryOption: nil,
                        options: modelStore.downloadedModels(for: .quickActions).map {
                            QuickstartModelOption(id: $0.id.rawValue, name: $0.id.name)
                        },
                        openExplore: openExplore
                    )
                    RequirementRow(requirement: .init(
                        id: "accessibility",
                        label: "Accessibility access",
                        detail: "Used to detect the shortcut across apps.",
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

    private func openExplore() {
        exploreState.filterTag = ModelStore.Feature.quickActions.pipelineTag
        exploreState.searchText = ""
        modelsState.selectedTab = .explore
        mainViewState.sidebarItem = .models
    }
}

#Preview {
    QuickActionsView()
        .environment(QuickActionsService(
            llmService: LLMService(),
            modelStore: ModelStore(),
            actionStore: ActionStore()
        ))
        .environment(MainViewState())
        .environment(ModelStore())
        .environment(ModelsViewState())
        .environment(ExploreViewState())
        .environment(PermissionsService())
        .frame(width: 800, height: 700)
}
