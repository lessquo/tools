import Foundation

@Observable
@MainActor
final class TextActionStore {

    private static let storageKey = "textActions"

    private(set) var actions: [TextAction] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([TextAction].self, from: data) {
            actions = decoded
        } else {
            actions = TextAction.defaults
            save()
        }
    }

    func add(_ action: TextAction) {
        actions.append(action)
        save()
    }

    func update(_ action: TextAction) {
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else { return }
        actions[index] = action
        save()
    }

    func delete(at offsets: IndexSet) {
        actions.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        actions.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func resetToDefaults() {
        actions = TextAction.defaults
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
