import AppKit
import AVFAudio
import HuggingFace
import SwiftUI

struct QuickstartView: View {
    @Environment(MainViewState.self) private var mainViewState
    @Environment(ModelStore.self) private var modelStore
    @Environment(ModelsViewState.self) private var modelsState
    @Environment(ExploreViewState.self) private var exploreState
    @Environment(FeaturesState.self) private var featuresState

    @State private var accessibilityGranted = ClipboardService.checkAccessibilityPermission()
    @State private var microphoneGranted = AVAudioApplication.shared.recordPermission == .granted

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
        .task {
            refreshPermissions()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                refreshPermissions()
            }
        }
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
                    isReady: accessibilityGranted,
                    actionLabel: "Grant",
                    readyActionLabel: "Settings",
                    action: ClipboardService.requestAccessibilityPermission,
                    readyAction: openAccessibilitySettings
                ))
                RequirementRow(requirement: .init(
                    id: "microphone",
                    label: "Microphone access",
                    detail: "Used to capture your voice for transcription.",
                    isReady: microphoneGranted,
                    actionLabel: "Grant",
                    readyActionLabel: "Settings",
                    action: requestMicrophone,
                    readyAction: openMicrophoneSettings
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
                    isReady: accessibilityGranted,
                    actionLabel: "Grant",
                    readyActionLabel: "Settings",
                    action: ClipboardService.requestAccessibilityPermission,
                    readyAction: openAccessibilitySettings
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
        // macOS only shows the system prompt while permission is .undetermined.
        // Once denied, the user has to toggle it back in System Settings.
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            Task {
                _ = await AVAudioApplication.requestRecordPermission()
                refreshPermissions()
            }
        case .denied:
            openMicrophoneSettings()
        case .granted:
            break
        @unknown default:
            break
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshPermissions() {
        accessibilityGranted = ClipboardService.checkAccessibilityPermission()
        microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
    }
}

#Preview {
    QuickstartView()
        .environment(FeaturesState())
        .environment(MainViewState())
        .environment(ModelStore())
        .environment(ModelsViewState())
        .environment(ExploreViewState())
        .frame(width: 800, height: 700)
}
