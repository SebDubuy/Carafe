import Foundation

/// Textes des notifications, tirés au hasard. Ton léger, jamais culpabilisant.
enum ReminderMessages {
    struct Message {
        let title: String
        let body: String
    }

    /// Rappel d'inactivité (et rappel reporté).
    static func inactivity() -> Message {
        let messages = [
            Message(title: String(localized: "Glouglou ?"),
                    body: String(localized: "Ça fait un moment… Une petite gorgée ?")),
            Message(title: String(localized: "Ton verre s'ennuie"),
                    body: String(localized: "Il n'attend que toi.")),
            Message(title: String(localized: "Une petite gorgée ?"),
                    body: String(localized: "Juste de quoi faire glouglou.")),
            Message(title: String(localized: "Pause eau ?"),
                    body: String(localized: "Deux minutes, un verre, et c'est reparti.")),
            Message(title: String(localized: "Hop, un verre ?"),
                    body: String(localized: "Ton corps te dira merci (en silence).")),
            Message(title: String(localized: "Coucou, c'est l'eau"),
                    body: String(localized: "On ne s'est pas vus depuis un moment.")),
        ]
        return messages.randomElement()!
    }

    /// Rappel de rythme, avec les quantités.
    static func pace(drunk: Int, expected: Int) -> Message {
        let titles = [
            String(localized: "Tu es un peu en retard"),
            String(localized: "Petit coup de pouce ?"),
            String(localized: "On rattrape en douceur ?"),
        ]
        let body = String(localized: "\(Formatters.liters(drunk)) bu, \(Formatters.liters(expected)) attendus à cette heure.")
        return Message(title: titles.randomElement()!, body: body)
    }
}
