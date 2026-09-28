import Foundation

/// Lecture / écriture des données dans UserDefaults, encodées en JSON.
/// Tout reste en local sur le Mac.
struct Persistence {
    private enum Key {
        static let entries = "entries"
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadEntries() -> [DrinkEntry] {
        load([DrinkEntry].self, forKey: Key.entries) ?? []
    }

    func saveEntries(_ entries: [DrinkEntry]) {
        save(entries, forKey: Key.entries)
    }

    // MARK: - Outils génériques

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
