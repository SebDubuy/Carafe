import AppKit

/// Petit son joué à chaque verre ajouté (désactivable dans les réglages).
@MainActor
enum SoundPlayer {
    /// Son système « Bottle » : une bulle discrète, en attendant un vrai « plouf » maison.
    private static let plouf: NSSound? = {
        let sound = NSSound(named: "Bottle")
        sound?.volume = 0.6
        return sound
    }()

    static func playPlouf(if enabled: Bool) {
        guard enabled, let sound = plouf else { return }
        // On relance depuis le début si deux verres sont ajoutés coup sur coup.
        sound.stop()
        sound.play()
    }
}
