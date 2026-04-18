import SwiftUI

struct DictationView: View {
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
                    title: "Dictation",
                    description: "Hold the fn key anywhere to dictate. Release to paste the transcript.",
                    systemImage: "mic",
                    shortcut: "fn",
                    isEnabled: $featuresState.dictationEnabled
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
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .navigationTitle("Dictation")
    }

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
    DictationView()
        .environment(FeaturesState())
        .environment(MainViewState())
        .environment(ModelStore())
        .environment(ModelsViewState())
        .environment(ExploreViewState())
        .environment(PermissionsService())
        .frame(width: 800, height: 700)
}
