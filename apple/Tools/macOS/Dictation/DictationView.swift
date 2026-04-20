import SwiftUI

struct DictationView: View {
    @Environment(HFService.self) private var hfService
    @Environment(ModelService.self) private var modelService
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
                    QuickstartShortcut(
                        shortcut: $dictationService.shortcut,
                        lockedMode: .hold,
                        defaultShortcut: .dictationDefault
                    )
                    QuickstartModel(
                        selectedID: $dictationService.modelID,
                        label: "Speech-to-text model",
                        modelName: modelService.modelName(id: dictationService.modelID),
                        isReady: modelService.isModelReady(id: dictationService.modelID),
                        primaryOption: QuickstartModelOption(
                            id: AppleSpeechService.modelID,
                            name: modelService.modelName(id: AppleSpeechService.modelID)
                        ),
                        options: hfService.downloadedModels(for: .dictation).map {
                            QuickstartModelOption(id: $0.id.rawValue, name: $0.id.name)
                        },
                        browseMoreLabel: "Browse Parakeet models…",
                        openExplore: openExplore
                    )
                    QuickstartPermission(requirement: .init(
                        id: "accessibility",
                        label: "Accessibility access",
                        detail: "Used to detect the shortcut across apps.",
                        isReady: permissions.isAccessibilityGranted,
                        actionLabel: "Grant",
                        readyActionLabel: "Settings",
                        action: permissions.requestAccessibility,
                        readyAction: permissions.openAccessibilitySettings
                    ))
                    QuickstartPermission(requirement: .init(
                        id: "microphone",
                        label: "Microphone access",
                        detail: "Used to capture your voice for transcription.",
                        isReady: permissions.isMicrophoneGranted,
                        actionLabel: "Grant",
                        readyActionLabel: "Settings",
                        action: requestMicrophone,
                        readyAction: permissions.openMicrophoneSettings
                    ))
                    if dictationService.modelID == AppleSpeechService.modelID {
                        QuickstartPermission(requirement: .init(
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
    let hf = HFService()
    let apple = AppleSpeechService()
    let model = ModelService(hfService: hf, appleSpeechService: apple)
    DictationView()
        .environment(DictationService(stt: STTService(hfService: hf, appleSpeechService: apple)))
        .environment(MainViewState())
        .environment(hf)
        .environment(model)
        .environment(ModelsViewState())
        .environment(ExploreViewState())
        .environment(PermissionsService())
        .frame(width: 800, height: 700)
}
