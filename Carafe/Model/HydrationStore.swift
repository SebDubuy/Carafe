import Combine
import Foundation

/// Bilan d'une journée, pour l'historique.
struct DaySummary: Identifiable, Equatable {
    /// Début de la journée (minuit, heure locale).
    let day: Date
    let total: Int
    let goal: Int

    var id: Date { day }
    var goalReached: Bool { goal > 0 && total >= goal }
    /// Remplissage entre 0 et 1 (plafonné).
    var progress: Double { goal > 0 ? min(Double(total) / Double(goal), 1) : 0 }
}

/// État central de l'app : les verres bus, la progression du jour et l'historique.
/// Toutes les vues (menu, icône) observent cet objet.
@MainActor
final class HydrationStore: ObservableObject {
    /// Tous les verres enregistrés (aujourd'hui + historique, jamais effacé à minuit).
    @Published private(set) var entries: [DrinkEntry]
    /// Jour en cours (minuit local). Change à minuit, au réveil ou au lancement :
    /// les vues se redessinent et le compteur du jour repart de zéro.
    @Published private(set) var currentDay: Date
    /// Objectif retenu pour chaque jour (clé « aaaa-mm-jj »), pour que l'historique
    /// reste juste même si l'objectif change plus tard.
    @Published private(set) var dailyGoals: [String: Int]
    /// Mode debug : décalage en jours pour simuler un changement de jour.
    @Published private(set) var debugDayOffset = 0

    /// Réglages (objectif, tailles de verre…).
    let settings: AppSettings

    /// Objectif quotidien en ml, tiré des réglages.
    var goalMilliliters: Int { settings.goalMilliliters }

    private let persistence: Persistence
    private let calendar: Calendar
    private let clock: () -> Date
    private var settingsObserver: AnyCancellable?

    init(settings: AppSettings,
         persistence: Persistence = Persistence(),
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init) {
        self.settings = settings
        self.persistence = persistence
        self.calendar = calendar
        self.clock = now
        self.entries = persistence.loadEntries()
        self.dailyGoals = persistence.loadDailyGoals()
        self.currentDay = calendar.startOfDay(for: now())
        // Un changement d'objectif doit redessiner l'icône et le menu,
        // et devient l'objectif retenu pour aujourd'hui.
        settingsObserver = settings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
            DispatchQueue.main.async { self?.recordTodayGoal() }
        }
    }

    // MARK: - Temps

    /// Heure actuelle (décalée en mode debug « jour suivant »).
    var now: Date {
        calendar.date(byAdding: .day, value: debugDayOffset, to: clock()) ?? clock()
    }

    /// À appeler à minuit, au réveil et au lancement : si le jour a changé,
    /// le compteur du jour repart de zéro (l'historique est conservé).
    func refreshDay() {
        let today = calendar.startOfDay(for: now)
        if today != currentDay {
            currentDay = today
        }
    }

    // MARK: - Aujourd'hui

    /// Verres bus aujourd'hui (jour local), du plus ancien au plus récent.
    var todayEntries: [DrinkEntry] {
        entries(on: now)
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

    /// Heure du dernier verre du jour.
    var lastDrinkToday: Date? {
        todayEntries.last?.date
    }

    // MARK: - Historique

    /// Les `days` derniers jours, du plus ancien à aujourd'hui inclus.
    func history(days: Int = 7) -> [DaySummary] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
            return summary(for: day)
        }
    }

    /// Nombre de jours d'affilée où l'objectif a été atteint. Aujourd'hui compte s'il est
    /// déjà atteint ; sinon la série court toujours jusqu'à hier (on a encore la journée).
    var streak: Int {
        let today = calendar.startOfDay(for: now)
        var count = summary(for: today).goalReached ? 1 : 0
        var day = today
        while let previous = calendar.date(byAdding: .day, value: -1, to: day),
              summary(for: previous).goalReached {
            count += 1
            day = previous
        }
        return count
    }

    private func summary(for day: Date) -> DaySummary {
        let total = entries(on: day).reduce(0) { $0 + $1.milliliters }
        let isToday = calendar.isDate(day, inSameDayAs: now)
        // Jours passés : l'objectif retenu ce jour-là ; à défaut, l'objectif actuel.
        let goal = isToday ? goalMilliliters : (dailyGoals[dayKey(day)] ?? goalMilliliters)
        return DaySummary(day: calendar.startOfDay(for: day), total: total, goal: goal)
    }

    private func entries(on day: Date) -> [DrinkEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: - Actions

    func add(milliliters: Int) {
        guard milliliters > 0 else { return }
        refreshDay()
        entries.append(DrinkEntry(milliliters: milliliters, date: now))
        persistence.saveEntries(entries)
        recordTodayGoal()
    }

    /// Supprime le dernier verre du jour (on ne touche jamais aux jours passés).
    func undoLast() {
        guard let last = todayEntries.last else { return }
        delete(id: last.id)
    }

    /// Supprime un verre précis (liste des verres du jour).
    func delete(id: DrinkEntry.ID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries.remove(at: index)
        persistence.saveEntries(entries)
    }

    // MARK: - Mode debug

    /// Simule le passage au jour suivant.
    func debugNextDay() {
        debugDayOffset += 1
        refreshDay()
    }

    /// Revient au vrai jour et efface les verres ajoutés « dans le futur » pendant la simulation.
    func debugBackToToday() {
        debugDayOffset = 0
        let realNow = clock()
        entries.removeAll { $0.date > realNow }
        persistence.saveEntries(entries)
        refreshDay()
    }

    // MARK: - Objectif retenu par jour

    private func recordTodayGoal() {
        let key = dayKey(now)
        guard dailyGoals[key] != goalMilliliters else { return }
        dailyGoals[key] = goalMilliliters
        persistence.saveDailyGoals(dailyGoals)
    }

    private func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
