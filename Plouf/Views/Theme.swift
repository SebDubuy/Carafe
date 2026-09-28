import SwiftUI

/// Couleurs et styles « eau » partagés par les vues de Plouf.
enum Theme {
    /// Bleu de l'eau (le même que dans l'icône de la barre de menus).
    static let water = Color(red: 0.18, green: 0.56, blue: 1.0)
    /// Bleu clair, presque turquoise, pour les dégradés.
    static let waterLight = Color(red: 0.36, green: 0.80, blue: 1.0)

    static let waterGradient = LinearGradient(colors: [waterLight, water],
                                              startPoint: .leading, endPoint: .trailing)

    /// Touche de bleu posée sur le verre du fond (très légère : on doit voir à travers).
    static let glassTint = NSColor(srgbRed: 0.18, green: 0.56, blue: 1.0, alpha: 0.10)
}

/// Fond « verre liquide » bleuté, commun au menu et à la fenêtre des réglages.
/// - macOS 26 et plus : vrai matériau Liquid Glass (`NSGlassEffectView`, style transparent).
/// - Avant : flou translucide classique (`NSVisualEffectView`) avec la même touche de bleu.
/// La fenêtre qui l'accueille doit être transparente pour qu'on voie à travers.
struct GlassBackground: NSViewRepresentable {
    /// Arrondi des coins, à caler sur celui de la fenêtre quand elle est transparente.
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.style = .clear
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
        let tint = NSView()
        tint.wantsLayer = true
        tint.layer?.backgroundColor = Theme.glassTint.cgColor
        tint.autoresizingMask = [.width, .height]
        blur.addSubview(tint)
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
