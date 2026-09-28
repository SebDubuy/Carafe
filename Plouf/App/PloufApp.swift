import SwiftUI

@main
struct PloufApp: App {
    @StateObject private var store = HydrationStore()

    var body: some Scene {
        MenuBarExtra {
            MenuView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Ce qui s'affiche dans la barre de menus : le verre (et plus tard le texte optionnel).
private struct MenuBarLabel: View {
    @ObservedObject var store: HydrationStore

    var body: some View {
        Image(nsImage: GlassIconRenderer.image(progress: store.progress))
    }
}
