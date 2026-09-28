import SwiftUI

/// Onglet caché (Option + clic sur « Réglages… » ou `--debug`) : état interne des rappels
/// et outils pour tester sans attendre.
struct DebugView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var scheduler: ReminderScheduler

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard("Rappels") {
                row("Prochain rappel", scheduler.decision?.nextDate.map(format) ?? "—")
                row("Raison", scheduler.decision?.reason ?? "—")
                row("Écran verrouillé / veille", scheduler.isAway ? "oui" : "non")
                row("Dernier rappel", scheduler.state.lastReminderAt.map(format) ?? "—")
                row("Dernier rappel de rythme", scheduler.state.lastPaceReminderAt.map(format) ?? "—")
                row("Rappel reporté jusqu'à", scheduler.state.snoozeUntil.map(format) ?? "—")
                row("Autorisation", authorizationText)
            }

            GlassCard("Outils") {
                HStack {
                    Text("Tous les délais à 1 minute")
                    Spacer()
                    Toggle("Tous les délais à 1 minute", isOn: $settings.debugShortDelays)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                HStack {
                    Button("Réévaluer maintenant") { scheduler.evaluate() }
                    Button("Envoyer un rappel test") { scheduler.sendTestReminder() }
                }
                Button("Quitter le mode debug") {
                    settings.debugShortDelays = false
                    settings.debugMode = false
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
    }

    private func format(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    private var authorizationText: String {
        switch scheduler.notifications.authorization {
        case .authorized, .provisional: return "autorisées"
        case .denied: return "refusées"
        case .notDetermined: return "pas encore demandé"
        default: return "inconnue"
        }
    }
}
