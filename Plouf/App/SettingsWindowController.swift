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
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
            // Barre de titre transparente et contenu dessous : le fond bleuté couvre toute la
            // fenêtre ; seuls les boutons rouge / orange / vert restent visibles.
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = String(localized: "Réglages de Plouf")
            window.isMovableByWindowBackground = true
            // Fenêtre transparente : c'est le verre liquide du fond qui fait tout le rendu.
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
