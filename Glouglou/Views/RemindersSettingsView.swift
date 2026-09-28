import AppKit
import SwiftUI

/// Onglet « Rappels » : plage horaire, rappel d'inactivité, rappel de rythme.
struct RemindersSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var scheduler: ReminderScheduler
    @ObservedObject var notifications: NotificationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if settings.debugMode && settings.debugShortDelays {
                GlassCard {
                    Label("Mode debug : tous les délais sont ramenés à 1 minute.", systemImage: "ladybug.fill")
                        .foregroundStyle(.orange)
                }
            }

            GlassCard {
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(Theme.waterLight)
                    Text(nextReminderText)
                    Spacer()
                }
            }

            if notifications.authorization == .denied {
                GlassCard {
                    Label("Les notifications de Glouglou sont désactivées.", systemImage: "bell.slash")
                        .font(.body.weight(.medium))
                    Caption("Autorise-les dans Réglages Système › Notifications › Glouglou pour recevoir les rappels.")
                    Button("Ouvrir les réglages des notifications") {
                        NotificationManager.openSystemSettings()
                    }
                }
            }

            GlassCard("Plage horaire") {
                HStack {
                    Text("De")
                    hourPicker(selection: $settings.activeStartHour, range: 0...22)
                    Text("à")
                    hourPicker(selection: $settings.activeEndHour, range: 1...23)
                    Spacer()
                }
                Caption("Aucun rappel en dehors de cette plage, ni quand l'écran est verrouillé.")
            }
            .onChange(of: settings.activeStartHour) { start in
                // La fin reste toujours après le début.
                if settings.activeEndHour <= start { settings.activeEndHour = start + 1 }
            }
            .onChange(of: settings.activeEndHour) { end in
                if settings.activeStartHour >= end { settings.activeStartHour = end - 1 }
            }

            GlassCard("Rappel d'inactivité") {
                HStack {
                    Text("Me rappeler de boire")
                    Spacer()
                    Toggle("Me rappeler de boire", isOn: $settings.inactivityReminderEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                if settings.inactivityReminderEnabled {
                    Picker("Après", selection: $settings.inactivityDelay) {
                        ForEach(InactivityDelay.allCases) { delay in
                            Text(Formatters.duration(minutes: delay.minutes)).tag(delay)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Caption("Si aucun verre n'a été ajouté depuis ce délai. Le compte à rebours repart à chaque verre.")
                }
            }

            GlassCard("Rappel de rythme") {
                HStack {
                    Text("Me prévenir si je suis en retard")
                    Spacer()
                    Toggle("Me prévenir si je suis en retard", isOn: $settings.paceReminderEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                Caption("L'objectif est réparti sur la plage horaire. Un rappel au plus par heure si le retard dépasse 20 %.")
            }

            Caption("Plus aucun rappel une fois l'objectif du jour atteint.")
                .padding(.leading, 4)
        }
        .onAppear { notifications.refreshAuthorization() }
    }

    /// « Prochain rappel vers 21:34 », ou la raison s'il n'y en a pas de prévu aujourd'hui.
    private var nextReminderText: String {
        guard let decision = scheduler.decision else { return String(localized: "Calcul du prochain rappel…") }
        if let date = decision.nextDate {
            let calendar = Calendar.current
            let time = date.formatted(date: .omitted, time: .shortened)
            if calendar.isDateInToday(date) {
                return String(localized: "Prochain rappel vers \(time)")
            }
            return String(localized: "Prochain rappel demain vers \(time)")
        }
        if scheduler.goalReachedToday {
            return String(localized: "Objectif atteint : plus de rappel aujourd'hui 🎉")
        }
        return String(localized: "Aucun rappel prévu pour l'instant")
    }

    private func hourPicker(selection: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Picker("", selection: selection) {
            ForEach(Array(range), id: \.self) { hour in
                Text("\(hour) h").tag(hour)
            }
        }
        .labelsHidden()
        .fixedSize()
    }
}
