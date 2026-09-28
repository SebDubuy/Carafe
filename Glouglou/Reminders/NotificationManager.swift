import Foundation
import UserNotifications

/// Envoi des notifications Glouglou : autorisation, actions, et un seul identifiant
/// pour que chaque rappel remplace le précédent au lieu de s'empiler.
@MainActor
final class NotificationManager: ObservableObject {
    static let reminderIdentifier = "glouglou.reminder"
    static let categoryIdentifier = "glouglou.reminder.category"
    static let addActionIdentifier = "glouglou.action.add"
    static let snoozeActionIdentifier = "glouglou.action.snooze"

    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    /// Demande l'autorisation (la première fois, macOS affiche la question).
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            Task { @MainActor in self?.refreshAuthorization() }
        }
    }

    func refreshAuthorization() {
        center.getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            Task { @MainActor in self?.authorization = status }
        }
    }

    /// Enregistre les actions de la notification. Le titre du bouton d'ajout suit
    /// le verre par défaut (« + 25 cl », « + 500 ml »…).
    func registerActions(addTitle: String) {
        let add = UNNotificationAction(identifier: Self.addActionIdentifier, title: addTitle, options: [])
        let snooze = UNNotificationAction(identifier: Self.snoozeActionIdentifier,
                                          title: String(localized: "Rappeler dans 15 min"), options: [])
        let category = UNNotificationCategory(identifier: Self.categoryIdentifier,
                                              actions: [add, snooze], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    /// Affiche un rappel tout de suite, en remplaçant le précédent s'il est encore affiché.
    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        let request = UNNotificationRequest(identifier: Self.reminderIdentifier, content: content, trigger: nil)
        center.add(request)
    }

    /// Retire le rappel affiché (par exemple quand on vient de boire : il n'est plus pertinent).
    func removeDelivered() {
        center.removeDeliveredNotifications(withIdentifiers: [Self.reminderIdentifier])
    }
}
