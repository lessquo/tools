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

    @discardableResult
    func addFromTemplate(_ template: Action) -> UUID {
        let copy = template.copy()
        actions.append(copy)
        save()
        return copy.id
    }

    @discardableResult
    func addFromTemplates(_ templates: [Action]) -> Set<UUID> {
        var newIDs: Set<UUID> = []
        for template in templates {
            let copy = template.copy()
            actions.append(copy)
            newIDs.insert(copy.id)
        }
        save()
        return newIDs
    }

    @discardableResult
    func duplicate(_ action: Action) -> UUID? {
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else { return nil }
        let copy = action.copy()
        actions.insert(copy, at: index + 1)
        save()
        return copy.id
    }

    func delete(ids: Set<UUID>) {
        actions.removeAll { ids.contains($0.id) }
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
