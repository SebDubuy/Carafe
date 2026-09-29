import AppKit
import SwiftUI

/// Ouvre la fenêtre des réglages.
/// On gère la fenêtre nous-mêmes plutôt que la scène `Settings` de SwiftUI : pour une app
/// sans icône dans le Dock, c'est la seule façon fiable de l'ouvrir au premier plan
/// sur toutes les versions de macOS à partir de la 13.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(scheduler: ReminderScheduler) {
        if window == nil {
            let root = SettingsView(settings: scheduler.settingsForUI, scheduler: scheduler)
            let window = NSWindow(contentViewController: NSHostingController(rootView: root))
            // Barre de titre transparente et contenu dessous : un seul fond uni pour toute la
            // fenêtre ; seuls les boutons rouge / orange / vert restent visibles.
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = String(localized: "Réglages de Carafe")
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
