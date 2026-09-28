import SwiftUI

/// Contenu de la fenêtre qui s'ouvre au clic sur l'icône.
struct MenuView: View {
    @ObservedObject var store: HydrationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            progressSection
            addButtons
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: - Progression du jour

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Aujourd'hui")
                .font(.headline)
            ProgressView(value: store.progress)
                .tint(.blue)
            Text("\(Formatters.litersValue(store.todayTotal)) L sur \(Formatters.liters(store.goalMilliliters))")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
            if store.goalReached {
                Text("Objectif atteint, bravo !")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Ajout rapide

    private var addButtons: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(store.glasses) { glass in
                Button {
                    store.add(milliliters: glass.milliliters)
                } label: {
                    VStack(spacing: 2) {
                        Text("+ \(Formatters.glass(glass.milliliters))")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                        if !glass.name.isEmpty {
                            Text(glass.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Bas du menu

    private var footer: some View {
        HStack {
            Button("Annuler le dernier ajout") {
                store.undoLast()
            }
            .disabled(!store.canUndo)
            Spacer()
            Button("Quitter") {
                NSApp.terminate(nil)
            }
        }
        .buttonStyle(.borderless)
    }
}
