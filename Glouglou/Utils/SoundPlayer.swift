import AppKit

/// Petit son joué à chaque verre ajouté (désactivable dans les réglages).
@MainActor
enum SoundPlayer {
    /// Son système « Bottle » : une bulle discrète, en attendant un vrai « glouglou » maison.
    private static let drinkSound: NSSound? = {
        let sound = NSSound(named: "Bottle")
        sound?.volume = 0.6
        return sound
    }()

    static func playDrinkSound(if enabled: Bool) {
        guard enabled, let sound = drinkSound else { return }
        // On relance depuis le début si deux verres sont ajoutés coup sur coup.
        sound.stop()
        sound.play()
    }
}
