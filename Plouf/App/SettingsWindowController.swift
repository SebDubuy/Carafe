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

    func show(settings: AppSettings) {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: hosting)
            window.title = String(localized: "Réglages de Plouf")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
