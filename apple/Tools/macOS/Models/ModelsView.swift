import SwiftUI

enum ModelsTab: String, CaseIterable {
    case downloaded = "Downloaded"
    case explore = "Explore"
}

@Observable
@MainActor
final class ModelsViewState {
    var selectedTab = ModelsTab.downloaded
}

struct ModelsView: View {
    @Environment(ModelsViewState.self) private var state

    var body: some View {
        @Bindable var state = state
        Group {
            switch state.selectedTab {
            case .downloaded: DownloadedView()
            case .explore: ExploreView()
            }
        }
        .navigationTitle("Models")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $state.selectedTab) {
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
        .environment(HFService())
        .environment(ModelsViewState())
        .environment(DownloadedViewState())
        .environment(ExploreViewState())
}
