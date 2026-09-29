import SwiftUI

/// Couleurs partagées par les vues de Glouglou : palette discrète.
/// Fond et textes suivent l'apparence normale de macOS ; un seul bleu doux et désaturé
/// (« bleu brume ») est réservé à ce qui se remplit : jauge, goutte, barres de la semaine.
enum Theme {
    /// Bleu brume de l'eau.
    static let water = Color(red: 0.42, green: 0.64, blue: 0.88)
    /// Bleu brume plus clair, pour les dégradés.
    static let waterLight = Color(red: 0.62, green: 0.80, blue: 0.95)

    static let waterGradient = LinearGradient(colors: [waterLight, water],
                                              startPoint: .leading, endPoint: .trailing)

    /// Couleur des interrupteurs, sélecteurs, etc. : le même bleu brume, discret.
    static let controlTint = water

    /// Teinte posée sur le verre du fond : aucune (verre neutre).
    static let glassTint: NSColor? = nil
}

/// Fond « verre liquide » neutre, commun au menu et à la fenêtre des réglages.
/// - macOS 26 et plus : vrai matériau Liquid Glass (`NSGlassEffectView`, style normal :
///   assez dépoli pour que le texte des fenêtres derrière ne se lise pas).
/// - Avant : flou translucide classique (`NSVisualEffectView`).
/// La fenêtre qui l'accueille doit être transparente pour qu'on voie à travers.
struct GlassBackground: NSViewRepresentable {
    /// Arrondi des coins, à caler sur celui de la fenêtre quand elle est transparente.
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.tintColor = Theme.glassTint
            glass.cornerRadius = cornerRadius
            return glass
        }
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = cornerRadius
        blur.layer?.masksToBounds = true
        if let color = Theme.glassTint {
            let tint = NSView()
            tint.wantsLayer = true
            tint.layer?.backgroundColor = color.cgColor
            tint.autoresizingMask = [.width, .height]
            blur.addSubview(tint)
        }
        return blur
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}


/// Jauge de progression bleue, en dégradé.
struct WaterProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // Rail toujours visible, même à 0 %, quel que soit le fond.
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                Capsule()
                    .fill(Theme.waterGradient)
                    .frame(width: max(proxy.size.width * min(max(progress, 0), 1), progress > 0 ? 10 : 0))
                    .shadow(color: Theme.water.opacity(0.35), radius: 3)
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
                .overlay(shape.strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
        }
    }
}
