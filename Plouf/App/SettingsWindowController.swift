import AppKit
import SwiftUI

/// Ouvre la fenêtre des réglages, avec des onglets à icônes dans la barre d'outils
/// (même présentation que les Réglages Système et les apps d'Apple).
/// On gère la fenêtre nous-mêmes plutôt que la scène `Settings` de SwiftUI : pour une app
/// sans icône dans le Dock, c'est la seule façon fiable de l'ouvrir au premier plan
/// sur toutes les versions de macOS à partir de la 13.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(settings: AppSettings) {
        if window == nil {
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            tabs.addTabViewItem(tab(String(localized: "Général"),
                                    image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil),
                                    height: 330,
                                    view: GeneralSettingsView(settings: settings)))
            tabs.addTabViewItem(tab(String(localized: "Verres"),
                                    image: GlassIconRenderer.templateGlass,
                                    height: 500,
                                    view: GlassesSettingsView(settings: settings)))

            let window = NSWindow(contentViewController: tabs)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.toolbarStyle = .preference
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Chaque onglet a une taille fixe : la fenêtre s'y adapte en changeant d'onglet.
    private func tab<Content: View>(_ label: String, image: NSImage?, height: CGFloat,
                                    view: Content) -> NSTabViewItem {
        let hosting = NSHostingController(rootView: view.frame(width: 460, height: height))
        // Le titre de l'onglet sélectionné devient le titre de la fenêtre.
        hosting.title = label
        let item = NSTabViewItem(viewController: hosting)
        item.label = label
        item.image = image
        return item
    }
}
