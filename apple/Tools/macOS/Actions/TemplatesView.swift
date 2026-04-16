import SwiftUI

@Observable
@MainActor
final class TemplatesViewState {
    var selectedTemplateIDs: Set<UUID> = []
}

struct TemplatesView: View {
    @Environment(ActionStore.self) private var store
    @Environment(TemplatesViewState.self) private var state
    @Environment(MyActionsViewState.self) private var myActionsState
    @Environment(ActionsViewState.self) private var actionsState

    private let templates = Action.templates

    var body: some View {
        @Bindable var state = state
        HSplitView {
            List(selection: $state.selectedTemplateIDs) {
                ForEach(templates) { template in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(template.name)
                            switch template.type {
                            case .script: Text("JS").badgeStyle()
                            case .workflow: Text("WF").badgeStyle()
                            case .llm: EmptyView()
                            }
                        }
                        Text(templateSubtitle(template))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(template.id)
                    .padding(.vertical, 4)
                    .contextMenu {
                        if state.selectedTemplateIDs.contains(template.id),
                           state.selectedTemplateIDs.count > 1 {
                            Button("Add \(state.selectedTemplateIDs.count) to My Actions") {
                                addSelectedTemplates()
                            }
                        } else {
                            Button("Add to My Actions") {
                                addTemplate(template)
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            if state.selectedTemplateIDs.count > 1 {
                MultiSelectionView(
                    actions: selectedTemplates,
                    buttonLabel: "Add All to My Actions",
                    buttonIcon: "plus",
                    buttonStyle: .borderedProminent
                ) {
                    addSelectedTemplates()
                }
            } else if let template = selectedTemplates.first {
                TemplateDetailView(template: template)
                    .id(template.id)
                    .frame(minWidth: 300, maxWidth: .infinity)
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "square.grid.2x2",
                    description: Text("Select a template to preview")
                )
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if state.selectedTemplateIDs.isEmpty {
                if let firstID = templates.first?.id {
                    state.selectedTemplateIDs = [firstID]
                }
            }
        }
    }

    private func templateSubtitle(_ action: Action) -> String {
        switch action.type {
        case .llm: action.prompt
        case .script: action.script
        case .workflow: "\(action.steps.count) step\(action.steps.count == 1 ? "" : "s")"
        }
    }

    private var selectedTemplates: [Action] {
        templates.filter { state.selectedTemplateIDs.contains($0.id) }
    }

    private func addTemplate(_ template: Action) {
        let newID = store.addFromTemplate(template)
        myActionsState.selectedActionIDs = [newID]
        actionsState.selectedTab = .myActions
    }

    private func addSelectedTemplates() {
        let newIDs = store.addFromTemplates(selectedTemplates)
        myActionsState.selectedActionIDs = newIDs
        actionsState.selectedTab = .myActions
    }
}

private struct TemplateDetailView: View {
    @Environment(ActionStore.self) private var store
    @Environment(MyActionsViewState.self) private var myActionsState
    @Environment(ActionsViewState.self) private var actionsState
    let template: Action

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(template.name)
                    .font(.title2.bold())
                switch template.type {
                case .script: Text("JS").badgeStyle()
                case .workflow: Text("WF").badgeStyle()
                case .llm: EmptyView()
                }
                Spacer()
                Button {
                    let newID = store.addFromTemplate(template)
                    myActionsState.selectedActionIDs = [newID]
                    actionsState.selectedTab = .myActions
                } label: {
                    Label("Add to My Actions", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            switch template.type {
            case .llm:
                ScrollView {
                    Text(template.prompt)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            case .script:
                ScrollView {
                    Text(template.script)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ScriptPreviewView(script: template.script)
            case .workflow:
                Text("\(template.steps.count) step\(template.steps.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(template.steps) { step in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(step.name)
                                .font(.body.bold())
                            if step.type == .script {
                                Text("JS").badgeStyle()
                            }
                        }
                        Text(step.type == .llm ? step.prompt : step.script)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.fill.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
            }
        }
        .padding()
    }
}
