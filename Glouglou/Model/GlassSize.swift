import Foundation

/// Une taille de verre proposée dans le menu (ex. « Ma gourde – 75 cl »).
struct GlassSize: Codable, Identifiable, Equatable {
    let id: UUID
    /// Nom libre ; vide = on affiche simplement la contenance.
    var name: String
    var milliliters: Int

    init(id: UUID = UUID(), name: String = "", milliliters: Int) {
        self.id = id
        self.name = name
        self.milliliters = milliliters
    }

    /// Tailles proposées au premier lancement : 15, 25, 33 et 50 cl.
    static let defaults: [GlassSize] = [150, 250, 330, 500].map { GlassSize(milliliters: $0) }
}
