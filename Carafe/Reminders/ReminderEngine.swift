import Foundation

/// Paramètres des rappels (tirés des réglages, ou raccourcis en mode debug).
struct ReminderConfig: Equatable {
    var inactivityEnabled = true
    /// Délai sans boire avant le rappel d'inactivité.
    var inactivityInterval: TimeInterval = 90 * 60
    var paceEnabled = true
    /// Le rappel de rythme se déclenche si le retard dépasse ce pourcentage du rythme attendu.
    var paceThreshold = 0.20
    /// Au plus un rappel de rythme par période.
    var paceMinimumGap: TimeInterval = 60 * 60
    /// Écart minimum entre deux rappels, quels qu'ils soient (évite les rafales).
    var minimumGap: TimeInterval = 15 * 60
    /// Durée d'un « Rappeler dans 15 min ».
    var snoozeDuration: TimeInterval = 15 * 60
    /// En début de plage, pas de rappel de rythme tant qu'on « devrait » avoir bu moins que ça.
    var paceMinimumExpected = 250
    /// Plage horaire active (heures pleines, heure locale).
    var activeStartHour = 9
    var activeEndHour = 19
}

/// Ce que le moteur a besoin de connaître à un instant donné.
struct ReminderInput {
    var now: Date
    var todayTotal: Int
    var goal: Int
    /// Dernier verre du jour (nil si rien bu aujourd'hui).
    var lastDrinkAt: Date?
}

/// Mémoire des rappels déjà envoyés (enregistrée entre deux lancements).
struct ReminderState: Codable, Equatable {
    var lastReminderAt: Date?
    var lastPaceReminderAt: Date?
    /// « Rappeler dans 15 min » : date du rappel reporté et moment où il a été demandé.
    var snoozeUntil: Date?
    var snoozeSetAt: Date?
}

/// Type de rappel à envoyer.
enum ReminderKind: Equatable {
    case inactivity
    case pace(drunk: Int, expected: Int)
    case snooze
}

/// Résultat d'une évaluation : un rappel à envoyer maintenant (ou pas),
/// la date du prochain rappel prévu et la raison, pour le mode debug.
struct ReminderDecision: Equatable {
    var due: ReminderKind?
    var nextDate: Date?
    var reason: String
}

/// Logique des rappels, sans effet de bord : on lui donne l'heure et l'état,
/// il répond « faut-il rappeler maintenant, et sinon quand ». Facile à tester.
struct ReminderEngine {
    var config: ReminderConfig
    var calendar: Calendar = .current

    func evaluate(_ input: ReminderInput, state: ReminderState) -> ReminderDecision {
        let now = input.now

        // 1. Objectif atteint : plus aucun rappel aujourd'hui.
        if input.goal > 0 && input.todayTotal >= input.goal {
            return ReminderDecision(due: nil, nextDate: nil, reason: "Objectif atteint : plus de rappel aujourd'hui.")
        }

        guard config.inactivityEnabled || config.paceEnabled else {
            return ReminderDecision(due: nil, nextDate: nil, reason: "Rappels désactivés.")
        }

        // 2. Plage horaire active.
        guard let window = activeWindow(on: now) else {
            return ReminderDecision(due: nil, nextDate: nil, reason: "Plage horaire invalide.")
        }
        if now < window.start {
            return ReminderDecision(due: nil, nextDate: window.start, reason: "Avant la plage horaire.")
        }
        if now >= window.end {
            return ReminderDecision(due: nil, nextDate: nextWindowStart(after: now),
                                    reason: "Après la plage horaire.")
        }

        // 3. Rappel reporté (« Rappeler dans 15 min »), sauf si on a bu entre-temps.
        if let until = state.snoozeUntil, let setAt = state.snoozeSetAt,
           !(input.lastDrinkAt.map { $0 > setAt } ?? false) {
            if now >= until {
                return ReminderDecision(due: .snooze, nextDate: nil, reason: "Rappel reporté arrivé à échéance.")
            }
            return ReminderDecision(due: nil, nextDate: until, reason: "Rappel reporté.")
        }

        // 4. Candidats : inactivité et rythme.
        var candidates: [(date: Date, kind: ReminderKind, reason: String)] = []
        let gapAfterLast = state.lastReminderAt.map { $0.addingTimeInterval(config.minimumGap) } ?? .distantPast

        if config.inactivityEnabled {
            // Le compte à rebours part du dernier verre, du début de la plage
            // ou du dernier rappel (le plus récent des trois).
            let reference = [input.lastDrinkAt, window.start, state.lastReminderAt]
                .compactMap { $0 }.max() ?? window.start
            let due = reference.addingTimeInterval(config.inactivityInterval)
            candidates.append((due, .inactivity, "Inactivité : pas de verre depuis \(Self.time(reference))."))
        }

        if config.paceEnabled, input.goal > 0,
           let paceDate = paceDueDate(input: input, window: window) {
            var due = max(paceDate, gapAfterLast)
            if let lastPace = state.lastPaceReminderAt {
                due = max(due, lastPace.addingTimeInterval(config.paceMinimumGap))
            }
            let expected = expectedAmount(at: max(due, now), window: window, goal: input.goal)
            candidates.append((due, .pace(drunk: input.todayTotal, expected: expected),
                               "Rythme : en retard sur l'objectif."))
        }

        // Les rappels prévus après la fin de la plage sont repoussés au lendemain.
        candidates = candidates.filter { $0.date < window.end }
        guard !candidates.isEmpty else {
            return ReminderDecision(due: nil, nextDate: nextWindowStart(after: now),
                                    reason: "Rien d'autre aujourd'hui.")
        }

        // 5. Un rappel est-il dû maintenant ? Le rappel de rythme, plus précis, passe en premier.
        let dueNow = candidates.filter { $0.date <= now }
        if let pace = dueNow.first(where: { if case .pace = $0.kind { return true } else { return false } }) {
            return ReminderDecision(due: pace.kind, nextDate: nil, reason: pace.reason)
        }
        if let first = dueNow.first {
            return ReminderDecision(due: first.kind, nextDate: nil, reason: first.reason)
        }
        let next = candidates.min(by: { $0.date < $1.date })!
        return ReminderDecision(due: nil, nextDate: next.date, reason: next.reason)
    }

    /// Vrai si rien n'a été bu depuis le délai d'inactivité, pendant la plage horaire
    /// et tant que l'objectif n'est pas atteint : l'icône passe alors en « alerte ».
    func isInactive(_ input: ReminderInput) -> Bool {
        guard config.inactivityEnabled,
              input.goal <= 0 || input.todayTotal < input.goal,
              let window = activeWindow(on: input.now),
              window.contains(input.now) else { return false }
        let reference = max(input.lastDrinkAt ?? window.start, window.start)
        return input.now.timeIntervalSince(reference) >= config.inactivityInterval
    }

    /// Met à jour l'état après l'envoi d'un rappel.
    func stateAfterSending(_ kind: ReminderKind, at now: Date, from state: ReminderState) -> ReminderState {
        var state = state
        state.lastReminderAt = now
        if case .pace = kind { state.lastPaceReminderAt = now }
        state.snoozeUntil = nil
        state.snoozeSetAt = nil
        return state
    }

    /// Met à jour l'état quand on choisit « Rappeler dans 15 min ».
    func stateAfterSnooze(at now: Date, from state: ReminderState) -> ReminderState {
        var state = state
        state.snoozeUntil = now.addingTimeInterval(config.snoozeDuration)
        state.snoozeSetAt = now
        return state
    }

    // MARK: - Rythme

    /// Quantité qu'on « devrait » avoir bue à `date`, l'objectif étant réparti
    /// linéairement sur la plage horaire.
    func expectedAmount(at date: Date, window: DateInterval, goal: Int) -> Int {
        let elapsed = min(max(date.timeIntervalSince(window.start), 0), window.duration)
        return Int((Double(goal) * elapsed / window.duration).rounded())
    }

    /// Moment où le retard dépassera le seuil, compte tenu de ce qui a déjà été bu.
    private func paceDueDate(input: ReminderInput, window: DateInterval) -> Date? {
        // Retard > seuil  ⇔  bu < attendu × (1 − seuil)  ⇔  attendu > bu / (1 − seuil)
        let threshold = Double(input.todayTotal) / (1 - config.paceThreshold)
        let needed = max(threshold + 1, Double(config.paceMinimumExpected))
        let fraction = needed / Double(input.goal)
        guard fraction < 1 else { return nil }
        return window.start.addingTimeInterval(fraction * window.duration)
    }

    // MARK: - Plage horaire

    func activeWindow(on date: Date) -> DateInterval? {
        guard config.activeEndHour > config.activeStartHour,
              let start = calendar.date(bySettingHour: config.activeStartHour, minute: 0, second: 0, of: date),
              let end = calendar.date(bySettingHour: config.activeEndHour, minute: 0, second: 0, of: date)
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    private func nextWindowStart(after date: Date) -> Date? {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
        return activeWindow(on: tomorrow)?.start
    }

    private static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
