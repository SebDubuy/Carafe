import SwiftUI

@main
struct GlouglouApp: App {
    /// Les objets de l'app vivent dans l'AppDelegate, qui reçoit aussi les actions des notifications.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(store: appDelegate.store, scheduler: appDelegate.scheduler)
        } label: {
            MenuBarLabel(store: appDelegate.store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Ce qui s'affiche dans la barre de menus : la goutte, et le texte optionnel à côté.
private struct MenuBarLabel: View {
    @ObservedObject var store: HydrationStore
    /// Apparence de la barre de menus, pour choisir la couleur du contour de la goutte.
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: DropIconRenderer.image(progress: store.progress,
                                                   darkMenuBar: colorScheme == .dark))
            if let text {
                Text(text)
                    .monospacedDigit()
            }
        }
    }

    /// « 1,2 / 2 L », « 60 % » ou rien, selon le réglage.
    private var text: String? {
        switch store.settings.menuBarDisplay {
        case .iconOnly:
            return nil
        case .liters:
            return "\(Formatters.litersValue(store.todayTotal, maxFractionDigits: 1)) / \(Formatters.liters(store.goalMilliliters))"
        case .percent:
            let ratio = store.goalMilliliters > 0 ? Double(store.todayTotal) / Double(store.goalMilliliters) : 0
            return Formatters.percent(ratio)
        }
    }
}
