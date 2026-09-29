import SwiftUI

/// Couleurs et styles partagés par les vues de Glouglou.
/// Apparence standard de macOS (fond, textes, séparateurs du système, sans effet de verre) ;
/// une seule couleur franche, le bleu du système, pour ce qui se remplit : jauge, goutte,
/// barres de la semaine.
enum Theme {
    /// Bleu de l'eau : le bleu du système (s'ajuste tout seul aux thèmes clair et sombre).
    static let water = Color(nsColor: .systemBlue)
    /// Version atténuée, pour les jours où l'objectif n'est pas atteint.
    static let waterLight = Color(nsColor: .systemBlue).opacity(0.45)

    static let waterGradient = LinearGradient(colors: [water, water],
                                              startPoint: .leading, endPoint: .trailing)

    /// Rail gris des barres de progression (comme les jauges système).
    static let track = Color.primary.opacity(0.12)
}

/// Barre de progression fine : rail gris, remplissage bleu uni.
struct WaterProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.track)
                Capsule()
                    .fill(Theme.water)
                    .frame(width: max(proxy.size.width * min(max(progress, 0), 1), progress > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
    }
}

/// Bouton d'ajout de verre : bouton système discret (fond gris léger, texte normal).
struct WaterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        configuration.label
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(shape.fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.07)))
            .contentShape(shape)
    }
}
