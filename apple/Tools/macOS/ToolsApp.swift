import SwiftUI

@main
struct ToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Window("Tools", id: "main") {
            MainView()
                .environment(appDelegate.navigationState)
                .environment(appDelegate.modelStore)
                .environment(appDelegate.modelsState)
                .environment(appDelegate.libraryState)
                .environment(appDelegate.exploreState)
                .environment(appDelegate.actionStore)
        }
        .defaultSize(width: 1200, height: 700)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Previous Sidebar Item") {
                    appDelegate.navigationState.sidebarItem = appDelegate.navigationState.sidebarItem.previous
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])

                Button("Next Sidebar Item") {
                    appDelegate.navigationState.sidebarItem = appDelegate.navigationState.sidebarItem.next
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])

                Divider()

                Button("Previous Tab") {
                    switch appDelegate.navigationState.sidebarItem {
                    case .actions:
                        appDelegate.actionStore.selectedTab = appDelegate.actionStore.selectedTab.previous
                    case .models:
                        appDelegate.modelsState.selectedTab = appDelegate.modelsState.selectedTab.previous
                    }
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

                Button("Next Tab") {
                    switch appDelegate.navigationState.sidebarItem {
                    case .actions:
                        appDelegate.actionStore.selectedTab = appDelegate.actionStore.selectedTab.next
                    case .models:
                        appDelegate.modelsState.selectedTab = appDelegate.modelsState.selectedTab.next
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
