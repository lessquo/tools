import Foundation

@Observable
@MainActor
final class ActionStore {

    private static let storageKey = "actions"

    private(set) var actions: [Action] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Action].self, from: data) {
            actions = decoded
        } else {
            actions = Action.defaults
            save()
        }
    }

    func add(_ action: Action) {
        actions.append(action)
        save()
    }

    func update(_ action: Action) {
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
        actions = Action.defaults
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
