import HuggingFace
import SwiftUI

struct QuickstartView: View {
    @Environment(MainViewState.self) private var mainViewState
    @Environment(ModelStore.self) private var modelStore
    @Environment(ModelsViewState.self) private var modelsState
    @Environment(ExploreViewState.self) private var exploreState
    @Environment(FeaturesState.self) private var featuresState
    @Environment(PermissionsService.self) private var permissions

    var body: some View {
        @Bindable var featuresState = featuresState
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                featuresSection(
                    dictationEnabled: $featuresState.dictationEnabled,
                    quickActionsEnabled: $featuresState.quickActionsEnabled
                )
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .navigationTitle("Quickstart")
    }

    // MARK: - Sections

    private func featuresSection(
        dictationEnabled: Binding<Bool>,
        quickActionsEnabled: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            QuickstartCard(
                title: "Dictation",
                description: "Hold the fn key anywhere to dictate. Release to paste the transcript.",
                systemImage: "mic",
                shortcut: "fn",
                isEnabled: dictationEnabled
            ) {
                ModelPickerRow(
                    feature: .dictation,
                    label: "Speech-to-text model",
                    openExplore: openExplore
                )
                RequirementRow(requirement: .init(
                    id: "accessibility",
                    label: "Accessibility access",
                    detail: "Used to detect the fn key across apps.",
                    isReady: permissions.isAccessibilityGranted,
                    actionLabel: "Grant",
                    readyActionLabel: "Settings",
                    action: permissions.requestAccessibility,
                    readyAction: permissions.openAccessibilitySettings
                ))
                RequirementRow(requirement: .init(
                    id: "microphone",
                    label: "Microphone access",
                    detail: "Used to capture your voice for transcription.",
                    isReady: permissions.isMicrophoneGranted,
                    actionLabel: "Grant",
                    readyActionLabel: "Settings",
                    action: requestMicrophone,
                    readyAction: permissions.openMicrophoneSettings
                ))
            }
            QuickstartCard(
                title: "Quick Actions",
                description: "Press ⌘; to run an action on selected text from any app.",
                systemImage: "bolt",
                shortcut: "⌘ ;",
                isEnabled: quickActionsEnabled
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
    }

    // MARK: - Helpers

    private func openExplore(filterTag: String) {
        exploreState.filterTag = filterTag
        modelsState.selectedTab = .explore
        mainViewState.sidebarItem = .models
    }

    private func requestMicrophone() {
        Task { await permissions.requestMicrophone() }
    }
}

#Preview {
    QuickstartView()
        .environment(FeaturesState())
        .environment(MainViewState())
        .environment(ModelStore())
        .environment(ModelsViewState())
        .environment(ExploreViewState())
        .environment(PermissionsService())
        .frame(width: 800, height: 700)
}
