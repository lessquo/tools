import SwiftUI

struct ModelsView: View {
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
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }
}

#Preview {
    ModelsView()
        .environment(ModelStore())
}
