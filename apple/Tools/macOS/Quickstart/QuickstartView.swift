import AppKit
import AVFAudio
import SwiftUI

struct QuickstartView: View {
    @Environment(MainViewState.self) private var mainViewState
    @Environment(ModelStore.self) private var modelStore
    @Environment(ModelsViewState.self) private var modelsState
    @Environment(ExploreViewState.self) private var exploreState

    @State private var accessibilityGranted = ClipboardService.checkAccessibilityPermission()
    @State private var microphoneGranted = AVAudioApplication.shared.recordPermission == .granted

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                featuresSection
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

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureCard(
                title: "Dictation",
                description: "Hold the fn key anywhere to dictate. Release to paste the transcript.",
                systemImage: "mic",
                shortcut: "fn",
                requirements: [
                    .init(
                        id: "stt-model",
                        label: "Speech-to-text model",
                        isReady: hasSTTModel,
                        actionLabel: "Install",
                        readyActionLabel: "Browse",
                        action: { openExplore(filterTag: "automatic-speech-recognition") }
                    ),
                    .init(
                        id: "accessibility",
                        label: "Accessibility access",
                        detail: "Used to detect the fn key across apps.",
                        isReady: accessibilityGranted,
                        actionLabel: "Grant",
                        action: ClipboardService.requestAccessibilityPermission
                    ),
                    .init(
                        id: "microphone",
                        label: "Microphone access",
                        detail: "Used to capture your voice for transcription.",
                        isReady: microphoneGranted,
                        actionLabel: "Grant",
                        action: requestMicrophone
                    ),
                ]
            )
            FeatureCard(
                title: "Action Panel",
                description: "Press ⌘; to run an action on selected text from any app.",
                systemImage: "bolt",
                shortcut: "⌘ ;",
                requirements: [
                    .init(
                        id: "chat-model",
                        label: "Text-generation model",
                        isReady: hasChatModel,
                        actionLabel: "Install",
                        readyActionLabel: "Browse",
                        action: { openExplore(filterTag: "text-generation") }
                    ),
                    .init(
                        id: "accessibility",
                        label: "Accessibility access",
                        detail: "Used to detect ⌘; across apps.",
                        isReady: accessibilityGranted,
                        actionLabel: "Grant",
                        action: ClipboardService.requestAccessibilityPermission
                    ),
                ]
            )
        }
    }

    // MARK: - Helpers

    private var hasSTTModel: Bool {
        modelStore.downloadedModels.contains { $0.pipelineTag == "automatic-speech-recognition" }
    }

    private var hasChatModel: Bool {
        modelStore.downloadedModels.contains { $0.pipelineTag == "text-generation" }
    }

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
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        case .granted:
            break
        @unknown default:
            break
        }
    }

    private func refreshPermissions() {
        accessibilityGranted = ClipboardService.checkAccessibilityPermission()
        microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
    }
}

// MARK: - Subviews

private struct FeatureCard: View {
    struct Requirement: Identifiable {
        let id: String
        let label: String
        var detail: String? = nil
        let isReady: Bool
        let actionLabel: String
        var readyActionLabel: String? = nil
        let action: () -> Void
    }

    let title: String
    let description: String
    let systemImage: String
    let shortcut: String
    let requirements: [Requirement]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 28, height: 28)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.title2).bold()
                    Text(shortcut)
                        .font(.caption)
                        .monospaced()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    ForEach(requirements) { req in
                        RequirementRow(requirement: req)
                    }
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .cardBackground()
    }
}

private struct RequirementRow: View {
    let requirement: FeatureCard.Requirement

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: requirement.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(requirement.isReady ? .green : .orange)
                .font(.footnote)
            VStack(alignment: .leading, spacing: 2) {
                Text(requirement.label)
                    .font(.callout)
                if let detail = requirement.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if !requirement.isReady {
                Button(requirement.actionLabel, action: requirement.action)
                    .controlSize(.small)
            } else if let readyLabel = requirement.readyActionLabel {
                Button(readyLabel, action: requirement.action)
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - Card style

private extension View {
    func cardBackground() -> some View {
        background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator)
            )
    }
}

#Preview {
    QuickstartView()
        .environment(MainViewState())
        .environment(ModelStore())
        .environment(ModelsViewState())
        .environment(ExploreViewState())
        .frame(width: 800, height: 700)
}
