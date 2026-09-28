import AppKit

/// Surveille le verrouillage de l'écran et la mise en veille du Mac.
/// Pendant ce temps, aucun rappel ; au retour, on prévient pour une seule réévaluation.
@MainActor
final class SystemStateMonitor {
    /// Vrai quand l'écran est verrouillé ou que le Mac (ou l'écran) est en veille.
    private(set) var isAway = false {
        didSet {
            guard isAway != oldValue else { return }
            onChange?(isAway)
        }
    }

    /// Appelé à chaque changement d'état (true = absent, false = de retour).
    var onChange: ((Bool) -> Void)?

    private var isLocked = false { didSet { update() } }
    private var isAsleep = false { didSet { update() } }
    private var screensAsleep = false { didSet { update() } }
    private var observers: [NSObjectProtocol] = []

    func start() {
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isLocked = true }
        })
        observers.append(distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isLocked = false }
        })

        let workspace = NSWorkspace.shared.notificationCenter
        let pairs: [(Notification.Name, (SystemStateMonitor) -> Void)] = [
            (NSWorkspace.willSleepNotification, { $0.isAsleep = true }),
            (NSWorkspace.didWakeNotification, { $0.isAsleep = false }),
            (NSWorkspace.screensDidSleepNotification, { $0.screensAsleep = true }),
            (NSWorkspace.screensDidWakeNotification, { $0.screensAsleep = false }),
        ]
        for (name, action) in pairs {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    action(self)
                }
            })
        }
    }

    private func update() {
        isAway = isLocked || isAsleep || screensAsleep
    }
}
