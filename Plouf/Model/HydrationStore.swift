import Combine
import Foundation

/// État central de l'app : les verres bus et la progression par rapport à l'objectif.
/// Toutes les vues (menu, icône) observent cet objet.
@MainActor
final class HydrationStore: ObservableObject {
    /// Tous les verres enregistrés (aujourd'hui + historique).
    @Published private(set) var entries: [DrinkEntry]
    /// Réglages (objectif, tailles de verre…).
    let settings: AppSettings

    /// Objectif quotidien en ml, tiré des réglages.
    var goalMilliliters: Int { settings.goalMilliliters }

    private let persistence: Persistence
    private let calendar: Calendar
    private let now: () -> Date
    private var settingsObserver: AnyCancellable?

    init(settings: AppSettings,
         persistence: Persistence = Persistence(),
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init) {
        self.settings = settings
        self.persistence = persistence
        self.calendar = calendar
        self.now = now
        self.entries = persistence.loadEntries()
        // Un changement d'objectif doit aussi redessiner l'icône et le menu.
        settingsObserver = settings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Lecture

    /// Verres bus aujourd'hui (jour local), du plus ancien au plus récent.
    var todayEntries: [DrinkEntry] {
        let today = now()
        return entries.filter { calendar.isDate($0.date, inSameDayAs: today) }
    }

    var todayTotal: Int {
        todayEntries.reduce(0) { $0 + $1.milliliters }
    }

    /// Progression du jour entre 0 et 1 (plafonnée à 1).
    var progress: Double {
        guard goalMilliliters > 0 else { return 0 }
        return min(Double(todayTotal) / Double(goalMilliliters), 1)
    }

    var goalReached: Bool {
        todayTotal >= goalMilliliters
    }

    var canUndo: Bool {
        !todayEntries.isEmpty
    }

    // MARK: - Actions

    func add(milliliters: Int) {
        guard milliliters > 0 else { return }
        entries.append(DrinkEntry(milliliters: milliliters, date: now()))
        persistence.saveEntries(entries)
    }

    /// Supprime le dernier verre du jour (on ne touche jamais aux jours passés).
    func undoLast() {
        guard let last = todayEntries.last,
              let index = entries.lastIndex(where: { $0.id == last.id }) else { return }
        entries.remove(at: index)
        persistence.saveEntries(entries)
    }
}
