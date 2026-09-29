import Foundation
import ServiceManagement

/// Lancement de Carafe à l'ouverture de session, via `SMAppService`.
/// L'état est lu directement auprès du système (l'utilisateur peut aussi le changer
/// dans Réglages Système › Général › Ouverture).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Active ou désactive le lancement au démarrage. Renvoie l'état réel après l'opération.
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Carafe – lancement au démarrage : \(error.localizedDescription)")
        }
        return isEnabled
    }
}
