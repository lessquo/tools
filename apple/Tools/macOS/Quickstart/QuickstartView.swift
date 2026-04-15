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
                    actionPanelEnabled: $featuresState.actionPanelEnabled
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
        actionPanelEnabled: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureCard(
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
            FeatureCard(
                title: "Action Panel",
                description: "Press ⌘; to run an action on selected text from any app.",
                systemImage: "bolt",
                shortcut: "⌘ ;",
                isEnabled: actionPanelEnabled
            ) {
                ModelPickerRow(
                    feature: .actionPanel,
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

// MARK: - Subviews

private struct FeatureCard<Rows: View>: View {
    let title: String
    let description: String
    let systemImage: String
    let shortcut: String
    @Binding var isEnabled: Bool
    @ViewBuilder let rows: () -> Rows

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
                    rows()
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(16)
        .cardBackground()
    }
}

private struct Requirement: Identifiable {
    let id: String
    let label: String
    var detail: String? = nil
    let isReady: Bool
    let actionLabel: String
    var readyActionLabel: String? = nil
    let action: () -> Void
    var readyAction: (() -> Void)? = nil
}

private struct RequirementRow: View {
    let requirement: Requirement

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
                Button(readyLabel, action: requirement.readyAction ?? requirement.action)
                    .controlSize(.small)
            }
        }
    }
}

private struct ModelPickerRow: View {
    @Environment(ModelStore.self) private var store

    let feature: ModelStore.Feature
    let label: String
    let openExplore: (String) -> Void

    var body: some View {
        let downloaded = store.downloadedModels(for: feature)
        let selectedID = store.modelID(for: feature)
        let selected = store.model(for: feature)
        let isReady = store.isModelDownloaded(for: feature)

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isReady ? .green : .orange)
                .font(.footnote)
            Text(label)
                .font(.callout)
            Spacer(minLength: 8)

            if downloaded.isEmpty {
                Button("Install") { openExplore(feature.pipelineTag) }
                    .controlSize(.small)
            } else {
                Menu {
                    ForEach(downloaded, id: \.id) { model in
                        Button {
                            store.setModelID(model.id.rawValue, for: feature)
                        } label: {
                            if model.id.rawValue == selectedID {
                                Label(model.id.name, systemImage: "checkmark")
                            } else {
                                Text(model.id.name)
                            }
                        }
                    }
                    Divider()
                    Button("Browse more…") { openExplore(feature.pipelineTag) }
                } label: {
                    Text(selected?.id.name ?? "Select model")
                }
                .fixedSize()
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
        .environment(FeaturesState())
        .environment(MainViewState())
        .environment(ModelStore())
        .environment(ModelsViewState())
        .environment(ExploreViewState())
        .frame(width: 800, height: 700)
}
