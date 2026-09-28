import Combine
import Foundation

/// Chef d'orchestre des rappels : réévalue régulièrement la situation avec `ReminderEngine`,
/// envoie les notifications, et se tait quand l'écran est verrouillé ou le Mac en veille.
@MainActor
final class ReminderScheduler: ObservableObject {
    /// Dernière décision du moteur (affichée en mode debug).
    @Published private(set) var decision: ReminderDecision?
    @Published private(set) var isAway = false
    @Published private(set) var state: ReminderState {
        didSet { saveState() }
    }

    let notifications = NotificationManager()

    private let store: HydrationStore
    private let monitor = SystemStateMonitor()
    private let defaults: UserDefaults
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private static let stateKey = "reminderState"

    init(store: HydrationStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.stateKey),
           let saved = try? JSONDecoder().decode(ReminderState.self, from: data) {
            state = saved
        } else {
            state = ReminderState()
        }
    }

    private var settings: AppSettings { store.settings }
    /// Réglages, pour la fenêtre des réglages.
    var settingsForUI: AppSettings { store.settings }
    var goalReachedToday: Bool { store.goalReached }

    /// Paramètres du moteur, tirés des réglages (tout à 1 minute en mode debug « délais courts »).
    var config: ReminderConfig {
        var config = ReminderConfig()
        config.inactivityEnabled = settings.inactivityReminderEnabled
        config.inactivityInterval = TimeInterval(settings.inactivityDelay.minutes * 60)
        config.paceEnabled = settings.paceReminderEnabled
        config.activeStartHour = settings.activeStartHour
        config.activeEndHour = settings.activeEndHour
        if settings.debugMode && settings.debugShortDelays {
            config.inactivityInterval = 60
            config.paceMinimumGap = 60
            config.minimumGap = 60
            config.snoozeDuration = 60
        }
        return config
    }

    // MARK: - Démarrage

    func start() {
        notifications.requestAuthorization()
        registerActions()

        monitor.onChange = { [weak self] away in
            guard let self else { return }
            self.isAway = away
            // Au retour : une seule réévaluation, donc au plus une notification,
            // et seulement si elle est toujours pertinente.
            if !away { self.evaluate() }
        }
        monitor.start()

        // Un verre ajouté : le rappel affiché n'a plus lieu d'être, et le compte à rebours repart.
        store.$entries
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.notifications.removeDelivered()
                    self?.evaluate()
                }
            }
            .store(in: &cancellables)

        // Réglages modifiés : nouveaux délais, nouveau titre pour le bouton d'ajout.
        settings.objectWillChange
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.registerActions()
                self?.evaluate()
            }
            .store(in: &cancellables)

        // Vérification toutes les 30 secondes : simple et robuste (la veille suspend le timer,
        // le réveil déclenche de toute façon une réévaluation).
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
        evaluate()
    }

    // MARK: - Évaluation

    func evaluate(now: Date = Date()) {
        notifications.refreshAuthorization()
        let engine = ReminderEngine(config: config)
        let input = ReminderInput(now: now,
                                  todayTotal: store.todayTotal,
                                  goal: store.goalMilliliters,
                                  lastDrinkAt: store.todayEntries.last?.date)
        var result = engine.evaluate(input, state: state)

        if isAway {
            // Écran verrouillé ou veille : on n'envoie rien, on réévaluera au retour.
            result.reason = "Écran verrouillé ou veille : rappel suspendu. (\(result.reason))"
            decision = result
            return
        }

        if let kind = result.due {
            send(kind)
            state = engine.stateAfterSending(kind, at: now, from: state)
            // Nouvelle évaluation pour afficher le prochain rappel prévu.
            decision = engine.evaluate(input, state: state)
        } else {
            decision = result
        }
    }

    private func send(_ kind: ReminderKind) {
        let message: ReminderMessages.Message
        switch kind {
        case .inactivity, .snooze:
            message = ReminderMessages.inactivity()
        case let .pace(drunk, expected):
            message = ReminderMessages.pace(drunk: drunk, expected: expected)
        }
        notifications.post(title: message.title, body: message.body)
    }

    // MARK: - Actions depuis la notification

    /// « + 25 cl » : ajoute le verre par défaut (l'icône se met à jour aussitôt).
    func addDefaultGlassFromNotification() {
        guard let glass = settings.defaultGlass else { return }
        store.add(milliliters: glass.milliliters)
        SoundPlayer.playDrinkSound(if: settings.soundEnabled)
    }

    /// « Rappeler dans 15 min ».
    func snooze(now: Date = Date()) {
        state = ReminderEngine(config: config).stateAfterSnooze(at: now, from: state)
        evaluate(now: now)
    }

    /// Mode debug : envoie tout de suite un rappel d'exemple.
    func sendTestReminder() {
        send(.inactivity)
    }

    private func registerActions() {
        let title = settings.defaultGlass.map { "+ \(Formatters.glass($0.milliliters, unit: settings.volumeUnit))" }
            ?? String(localized: "+ 1 verre")
        notifications.registerActions(addTitle: title)
    }

    private func saveState() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.stateKey)
        }
    }
}
