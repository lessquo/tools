import SwiftUI

struct DictationView: View {
    @Environment(ModelStore.self) private var modelStore
    @Environment(ModelsViewState.self) private var modelsState
    @Environment(ExploreViewState.self) private var exploreState
    @Environment(MainViewState.self) private var mainViewState
    @Environment(DictationService.self) private var dictationService
    @Environment(PermissionsService.self) private var permissions

    var body: some View {
        @Bindable var dictationService = dictationService
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                QuickstartCard(
                    title: "Dictation",
                    description: "Hold the shortcut anywhere to dictate. Release to paste the transcript.",
                    systemImage: "mic",
                    shortcut: dictationService.shortcut.display,
                    isEnabled: $dictationService.isEnabled
                ) {
                    ShortcutSettingRow(
                        shortcut: $dictationService.shortcut,
                        lockedMode: .hold,
                        defaultShortcut: .dictationDefault
                    )
                    ModelPickerRow(
                        feature: .dictation,
                        label: "Speech-to-text model",
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
                    if modelStore.modelID(for: .dictation) == STTService.appleSpeechID {
                        RequirementRow(requirement: .init(
                            id: "speech-recognition",
                            label: "Speech recognition access",
                            detail: "Used by Apple Speech to transcribe audio on-device.",
                            isReady: permissions.isSpeechRecognitionGranted,
                            actionLabel: "Grant",
                            readyActionLabel: "Settings",
                            action: requestSpeechRecognition,
                            readyAction: permissions.openSpeechRecognitionSettings
                        ))
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .navigationTitle("Dictation")
    }

    private func openExplore() {
        exploreState.filterTag = ""
        exploreState.searchText = "parakeet"
        modelsState.selectedTab = .explore
        mainViewState.sidebarItem = .models
    }

    private func requestMicrophone() {
        Task { await permissions.requestMicrophone() }
    }

    private func requestSpeechRecognition() {
        Task { await permissions.requestSpeechRecognition() }
    }
}

#Preview {
    DictationView()
        .environment(DictationService(modelStore: ModelStore()))
        .environment(MainViewState())
        .environment(ModelStore())
        .environment(ModelsViewState())
        .environment(ExploreViewState())
        .environment(PermissionsService())
        .frame(width: 800, height: 700)
}
