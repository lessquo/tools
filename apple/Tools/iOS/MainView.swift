import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Models") {
                    ModelsView()
                }
                NavigationLink("API Keys") {
                    APIKeysView()
                }
                NavigationLink("Settings") {
                    SettingsView()
                }
            }
            .navigationTitle("Tools")
        }
    }
}

#Preview {
    MainView()
}
