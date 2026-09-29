import AppKit

/// Prévient quand le jour a (peut-être) changé : à minuit pile, quand macOS signale
/// un changement de date (fuseau, heure modifiée…) et au réveil du Mac.
/// Le changement réel est vérifié par `HydrationStore.refreshDay()`.
@MainActor
final class DayClock {
    var onDayMayHaveChanged: (() -> Void)?

    private var midnightTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    func start() {
        observers.append(NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.fire() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.fire() }
        })
        scheduleMidnight()
    }

    private func fire() {
        onDayMayHaveChanged?()
        scheduleMidnight()
    }

    /// Minuterie calée sur le prochain minuit (+1 s de marge).
    private func scheduleMidnight() {
        midnightTimer?.invalidate()
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) else { return }
        let timer = Timer(fire: tomorrow.addingTimeInterval(1), interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.fire() }
        }
        RunLoop.main.add(timer, forMode: .common)
        midnightTimer = timer
    }
}
