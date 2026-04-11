import SwiftUI

struct ModelsView: View {
    @Environment(ModelStore.self) private var store
    @State private var selectedTab = Tab.library

    enum Tab: String, CaseIterable {
        case library = "Library"
        case explore = "Explore"
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .library: LibraryView()
            case .explore: ExploreView()
            }
        }
        .navigationTitle("Models")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            ToolbarItem {
                Button {
                    NSWorkspace.shared.open(store.cacheDirectory)
                } label: {
                    Image(systemName: "folder")
                }
                .help("Show in Finder")
            }
        }
    }
}

#Preview {
    ModelsView()
        .environment(ModelStore())
}
