import SwiftUI

struct ModelsView: View {
    @Environment(ModelStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Group {
            switch store.selectedTab {
            case .library: LibraryView()
            case .explore: ExploreView()
            }
        }
        .navigationTitle("Models")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $store.selectedTab) {
                    ForEach(ModelsTab.allCases, id: \.self) { Text($0.rawValue) }
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
