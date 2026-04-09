import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Models") {
                    ModelsView()
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
    ContentView()
}
