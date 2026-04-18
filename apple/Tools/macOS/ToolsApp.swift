import SwiftUI

@main
struct ToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Window("Tools", id: "main") {
            MainView()
                .environment(appDelegate.mainViewState)
                .environment(appDelegate.dictationService)
                .environment(appDelegate.quickActionsService)
                .environment(appDelegate.actionStore)
                .environment(appDelegate.actionsState)
                .environment(appDelegate.myActionsState)
                .environment(appDelegate.templatesState)
                .environment(appDelegate.modelStore)
                .environment(appDelegate.modelsState)
                .environment(appDelegate.libraryState)
                .environment(appDelegate.exploreState)
                .environment(appDelegate.apiKeyStore)
                .environment(appDelegate.permissionsService)
        }
        .defaultSize(width: 1200, height: 700)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Previous Sidebar Item") {
                    appDelegate.mainViewState.sidebarItem = appDelegate.mainViewState.sidebarItem.previous
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])

                Button("Next Sidebar Item") {
                    appDelegate.mainViewState.sidebarItem = appDelegate.mainViewState.sidebarItem.next
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])

                Divider()

                Button("Previous Tab") {
                    switch appDelegate.mainViewState.sidebarItem {
                    case .actions:
                        appDelegate.actionsState.selectedTab = appDelegate.actionsState.selectedTab.previous
                    case .models:
                        appDelegate.modelsState.selectedTab = appDelegate.modelsState.selectedTab.previous
                    case .dictation, .quickActions, .apiKeys, .shortcuts:
                        break
                    }
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

                Button("Next Tab") {
                    switch appDelegate.mainViewState.sidebarItem {
                    case .actions:
                        appDelegate.actionsState.selectedTab = appDelegate.actionsState.selectedTab.next
                    case .models:
                        appDelegate.modelsState.selectedTab = appDelegate.modelsState.selectedTab.next
                    case .dictation, .quickActions, .apiKeys, .shortcuts:
                        break
                    }
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            }
        }
        Settings {
            SettingsView()
                .environment(appDelegate.actionStore)
        }
    }
}
