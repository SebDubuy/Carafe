import SwiftUI

/// Couleurs et styles « eau » partagés par les vues de Plouf.
enum Theme {
    /// Bleu de l'eau (le même que dans l'icône de la barre de menus).
    static let water = Color(red: 0.18, green: 0.56, blue: 1.0)
    /// Bleu clair, presque turquoise, pour les dégradés.
    static let waterLight = Color(red: 0.36, green: 0.80, blue: 1.0)

    static let waterGradient = LinearGradient(colors: [waterLight, water],
                                              startPoint: .leading, endPoint: .trailing)

    /// Fond du menu : un voile bleu qui s'estompe vers le bas.
    static let menuBackground = LinearGradient(colors: [water.opacity(0.30), water.opacity(0.06)],
                                               startPoint: .top, endPoint: .bottom)
}

/// Jauge de progression bleue, en dégradé.
struct WaterProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.water.opacity(0.15))
                Capsule()
                    .fill(Theme.waterGradient)
                    .frame(width: max(proxy.size.width * min(max(progress, 0), 1), progress > 0 ? 10 : 0))
                    .shadow(color: Theme.water.opacity(0.5), radius: 4)
            }
        }
        .frame(height: 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
    }
}

/// Bouton d'ajout de verre : verre liquide teinté de bleu sur macOS 26 et plus,
/// bouton bleu translucide sur les versions précédentes.
struct WaterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let label = configuration.label
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)

        if #available(macOS 26, *) {
            label.glassEffect(.regular.tint(Theme.water.opacity(0.35)).interactive(), in: shape)
        } else {
            label
                .background(shape.fill(Theme.water.opacity(configuration.isPressed ? 0.35 : 0.22)))
                .overlay(shape.strokeBorder(Theme.waterLight.opacity(0.45), lineWidth: 1))
        }
    }
}
