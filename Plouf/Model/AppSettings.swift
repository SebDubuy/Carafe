import Foundation

/// Façon de calculer l'objectif quotidien.
enum GoalMode: String, Codable, CaseIterable {
    /// Objectif fixe, réglable par pas de 0,25 L.
    case fixed
    /// Objectif calculé depuis le poids : kg × 33 ml, arrondi à 0,1 L.
    case weight
}

/// Unité d'affichage et de saisie des contenances de verre.
/// Les quantités sont toujours stockées en ml ; le total du jour reste affiché en litres.
enum VolumeUnit: String, Codable, CaseIterable {
    case centiliters
    case milliliters

    var symbol: String {
        switch self {
        case .centiliters: return "cl"
        case .milliliters: return "ml"
        }
    }

    /// Nombre de ml dans une unité.
    private var millilitersPerUnit: Double {
        self == .centiliters ? 10 : 1
    }

    func value(fromMilliliters ml: Int) -> Double {
        Double(ml) / millilitersPerUnit
    }

    func milliliters(from value: Double) -> Int {
        Int((value * millilitersPerUnit).rounded())
    }
}

/// Ce qui s'affiche à côté de l'icône dans la barre de menus.
enum MenuBarDisplay: String, Codable, CaseIterable {
    case iconOnly
    case liters
    case percent
}

/// Préférences de l'utilisateur, enregistrées dans UserDefaults à chaque modification.
@MainActor
final class AppSettings: ObservableObject {
    // Bornes des réglages.
    static let fixedGoalRange = 500...6000
    static let fixedGoalStep = 250
    static let weightRange = 30...200
    /// Contenance d'un verre en ml : de 1 cl à 5 L.
    static let glassRange = 10...5000

    @Published var goalMode: GoalMode { didSet { save() } }
    /// Objectif fixe en ml.
    @Published var fixedGoalMilliliters: Int { didSet { save() } }
    /// Poids en kg (utilisé si `goalMode == .weight`).
    @Published var weightKilograms: Int { didSet { save() } }
    @Published var glasses: [GlassSize] { didSet { save() } }
    /// Verre utilisé par défaut (action des notifications).
    @Published var defaultGlassID: UUID? { didSet { save() } }
    @Published var menuBarDisplay: MenuBarDisplay { didSet { save() } }
    @Published var volumeUnit: VolumeUnit { didSet { save() } }
    @Published var soundEnabled: Bool { didSet { save() } }

    private let defaults: UserDefaults
    private var isLoading = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = Self.load(from: defaults)
        goalMode = stored.goalMode
        fixedGoalMilliliters = stored.fixedGoalMilliliters
        weightKilograms = stored.weightKilograms
        glasses = stored.glasses
        defaultGlassID = stored.defaultGlassID ?? stored.glasses.first(where: { $0.milliliters == 250 })?.id
        menuBarDisplay = stored.menuBarDisplay
        volumeUnit = stored.volumeUnit
        soundEnabled = stored.soundEnabled
        isLoading = false
    }

    // MARK: - Valeurs calculées

    /// Objectif du jour en ml, selon le mode choisi.
    var goalMilliliters: Int {
        switch goalMode {
        case .fixed:
            return fixedGoalMilliliters
        case .weight:
            return Self.goalFromWeight(weightKilograms)
        }
    }

    /// kg × 33 ml, arrondi au décilitre (0,1 L).
    static func goalFromWeight(_ kilograms: Int) -> Int {
        Int((Double(kilograms * 33) / 100).rounded()) * 100
    }

    /// Verre par défaut ; à défaut, le premier de la liste.
    var defaultGlass: GlassSize? {
        glasses.first(where: { $0.id == defaultGlassID }) ?? glasses.first
    }

    // MARK: - Tailles de verre

    func addGlass() {
        let glass = GlassSize(milliliters: 250)
        glasses.append(glass)
        if defaultGlassID == nil { defaultGlassID = glass.id }
    }

    func removeGlass(id: UUID) {
        // On garde toujours au moins un verre.
        guard glasses.count > 1 else { return }
        glasses.removeAll { $0.id == id }
        if defaultGlassID == id { defaultGlassID = glasses.first?.id }
    }

    // MARK: - Persistance

    /// Forme enregistrée des réglages (tous les champs sont optionnels pour rester
    /// compatible si on en ajoute plus tard).
    private struct Stored: Codable {
        var goalMode: GoalMode = .fixed
        var fixedGoalMilliliters: Int = 2000
        var weightKilograms: Int = 70
        var glasses: [GlassSize] = GlassSize.defaults
        var defaultGlassID: UUID?
        var menuBarDisplay: MenuBarDisplay = .iconOnly
        var volumeUnit: VolumeUnit = .centiliters
        var soundEnabled: Bool = true

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Stored()
            goalMode = (try? c.decode(GoalMode.self, forKey: .goalMode)) ?? d.goalMode
            fixedGoalMilliliters = (try? c.decode(Int.self, forKey: .fixedGoalMilliliters)) ?? d.fixedGoalMilliliters
            weightKilograms = (try? c.decode(Int.self, forKey: .weightKilograms)) ?? d.weightKilograms
            glasses = (try? c.decode([GlassSize].self, forKey: .glasses)) ?? d.glasses
            defaultGlassID = try? c.decode(UUID.self, forKey: .defaultGlassID)
            menuBarDisplay = (try? c.decode(MenuBarDisplay.self, forKey: .menuBarDisplay)) ?? d.menuBarDisplay
            volumeUnit = (try? c.decode(VolumeUnit.self, forKey: .volumeUnit)) ?? d.volumeUnit
            soundEnabled = (try? c.decode(Bool.self, forKey: .soundEnabled)) ?? d.soundEnabled
        }
    }

    private static let key = "settings"

    private static func load(from defaults: UserDefaults) -> Stored {
        guard let data = defaults.data(forKey: key),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            // Premier lancement : on reprend les verres éventuellement enregistrés par l'étape 1.
            var fresh = Stored()
            if let data = defaults.data(forKey: "glasses"),
               let glasses = try? JSONDecoder().decode([GlassSize].self, from: data), !glasses.isEmpty {
                fresh.glasses = glasses
            }
            return fresh
        }
        return stored
    }

    private func save() {
        guard !isLoading else { return }
        var stored = Stored()
        stored.goalMode = goalMode
        stored.fixedGoalMilliliters = fixedGoalMilliliters
        stored.weightKilograms = weightKilograms
        stored.glasses = glasses
        stored.defaultGlassID = defaultGlassID
        stored.menuBarDisplay = menuBarDisplay
        stored.volumeUnit = volumeUnit
        stored.soundEnabled = soundEnabled
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
