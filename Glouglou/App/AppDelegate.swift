import AppKit
import UserNotifications

/// Point d'entrée « AppKit » : crée les objets de l'app, démarre les rappels et
/// reçoit les clics sur les boutons des notifications.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let store = HydrationStore(settings: AppSettings())
    lazy var scheduler = ReminderScheduler(store: store)
    private let dayClock = DayClock()

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Le délégué doit être en place avant la fin du lancement, pour recevoir
        // un clic sur une notification qui aurait lancé l'app.
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pendant les tests unitaires, l'app sert d'hôte : pas de vraies notifications.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        // Remise à zéro quotidienne : vérifiée au lancement, à minuit et au réveil.
        store.refreshDay()
        dayClock.onDayMayHaveChanged = { [weak self] in
            self?.store.refreshDay()
            self?.scheduler.evaluate()
        }
        dayClock.start()
        scheduler.start()
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Glouglou vit dans la barre de menus, donc elle est toujours « au premier plan » :
    /// sans ça, macOS n'afficherait pas nos rappels.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        Task { @MainActor in
            switch action {
            case NotificationManager.addActionIdentifier:
                self.scheduler.addDefaultGlassFromNotification()
            case NotificationManager.snoozeActionIdentifier:
                self.scheduler.snooze()
            default:
                break
            }
            completionHandler()
        }
    }
}
