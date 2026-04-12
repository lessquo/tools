import SwiftUI

struct ActionTemplatesView: View {
    @Environment(ActionStore.self) private var store

    private let templates = Action.templates

    var body: some View {
        @Bindable var store = store
        HSplitView {
            List(selection: $store.selectedTemplateIDs) {
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 16, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(template.name)
                                if template.type == .script {
                                    Text("JS").badgeStyle()
                                }
                            }
                            Text(template.type == .llm ? template.prompt : template.script)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .tag(template.id)
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button("Add to My Actions") {
                            store.addFromTemplate(template)
                        }
                    }
                }
            }
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            if store.selectedTemplateIDs.count > 1 {
                MultiTemplateDetailView(templates: selectedTemplates)
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
            if store.selectedTemplateIDs.isEmpty {
                if let firstID = templates.first?.id {
                    store.selectedTemplateIDs = [firstID]
                }
            }
        }
    }

    private var selectedTemplates: [Action] {
        templates.filter { store.selectedTemplateIDs.contains($0.id) }
    }
}

private struct MultiTemplateDetailView: View {
    @Environment(ActionStore.self) private var store
    let templates: [Action]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(templates.count) templates selected")
                    .font(.title3.bold())
                Spacer()
                Button {
                    store.addFromTemplates(templates)
                } label: {
                    Label("Add All to My Actions", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            List {
                ForEach(templates) { template in
                    HStack(spacing: 4) {
                        Text(template.name)
                        if template.type == .script {
                            Text("JS").badgeStyle()
                        }
                    }
                }
            }
        }
        .padding()
    }
}

private struct TemplateDetailView: View {
    @Environment(ActionStore.self) private var store
    let template: Action

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(template.name)
                    .font(.title3.bold())
                if template.type == .script {
                    Text("JS").badgeStyle()
                }
                Spacer()
                Button {
                    store.addFromTemplate(template)
                } label: {
                    Label("Add to My Actions", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            ScrollView {
                Text(template.type == .llm ? template.prompt : template.script)
                    .font(template.type == .script ? .system(.body, design: .monospaced) : .body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }
}
