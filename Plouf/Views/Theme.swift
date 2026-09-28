import SwiftUI

/// Couleurs et styles « eau » partagés par les vues de Plouf.
enum Theme {
    /// Bleu de l'eau (le même que dans l'icône de la barre de menus).
    static let water = Color(red: 0.18, green: 0.56, blue: 1.0)
    /// Bleu clair, presque turquoise, pour les dégradés.
    static let waterLight = Color(red: 0.36, green: 0.80, blue: 1.0)

    static let waterGradient = LinearGradient(colors: [waterLight, water],
                                              startPoint: .leading, endPoint: .trailing)

    /// Voile bleu très léger et uniforme, commun au menu et aux réglages.
    static let tint = water.opacity(0.12)
}

/// Fond « verre bleuté » : flou de ce qui est derrière la fenêtre + voile bleu très léger.
/// Utilisé tel quel par le menu et la fenêtre des réglages pour qu'ils se ressemblent.
struct GlassBackground: View {
    var body: some View {
        ZStack {
            VisualEffectBackground()
            Theme.tint
        }
        .ignoresSafeArea()
    }
}

/// Flou natif macOS (`NSVisualEffectView`) derrière la fenêtre.
private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

extension View {
    /// Habillage d'un formulaire de réglages : fond transparent (le verre bleuté de la fenêtre
    /// passe dessous), contenu collé en haut et contrôles bleus.
    func waterFormStyle() -> some View {
        self
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .tint(Theme.water)
    }
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

/// Bouton d'ajout de verre : verre liquide clair (non rempli) avec le texte en bleu,
/// pour ne pas donner l'impression que les verres sont déjà pleins.
/// Sur macOS 13 à 15, bouton translucide avec un fin liseré bleu.
struct WaterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let label = configuration.label
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)

        if #available(macOS 26, *) {
            label.glassEffect(.regular.interactive(), in: shape)
        } else {
            label
                .background(shape.fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06)))
                .overlay(shape.strokeBorder(Theme.water.opacity(0.35), lineWidth: 1))
        }
    }
}
