import AppKit
import SwiftUI

/// Onglet « Rappels » : plage horaire, rappel d'inactivité, rappel de rythme.
struct RemindersSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var notifications: NotificationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if notifications.authorization == .denied {
                GlassCard {
                    Label("Les notifications de Plouf sont désactivées.", systemImage: "bell.slash")
                        .font(.body.weight(.medium))
                    Caption("Autorise-les dans Réglages Système › Notifications › Plouf pour recevoir les rappels.")
                    Button("Ouvrir les réglages des notifications") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
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
