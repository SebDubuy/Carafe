import SwiftUI

/// Contenu de la fenêtre qui s'ouvre au clic sur l'icône.
struct MenuView: View {
    @ObservedObject var store: HydrationStore
    /// Quantité libre saisie, dans l'unité choisie (cl ou ml).
    @State private var customAmount: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            progressSection
            addButtons
            customAmountRow
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
            ForEach(store.settings.glasses) { glass in
                Button {
                    store.add(milliliters: glass.milliliters)
                } label: {
                    VStack(spacing: 2) {
                        Text("+ \(Formatters.glass(glass.milliliters, unit: unit))")
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

    // MARK: - Quantité libre

    private var unit: VolumeUnit { store.settings.volumeUnit }

    private var customAmountRow: some View {
        HStack(spacing: 6) {
            Text("Autre quantité")
                .foregroundStyle(.secondary)
            Spacer()
            TextField("", value: $customAmount, format: .number.grouping(.never),
                      prompt: Text(unit == .centiliters ? "40" : "400"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .onSubmit(addCustomAmount)
            Text(unit.symbol)
                .foregroundStyle(.secondary)
            Button("Ajouter", action: addCustomAmount)
                .disabled(!isCustomAmountValid)
        }
        .font(.callout)
    }

    /// Quantité libre convertie en ml, si elle est dans les bornes autorisées.
    private var customMilliliters: Int? {
        guard let value = customAmount else { return nil }
        let ml = unit.milliliters(from: value)
        return AppSettings.glassRange.contains(ml) ? ml : nil
    }

    private var isCustomAmountValid: Bool { customMilliliters != nil }

    private func addCustomAmount() {
        guard let ml = customMilliliters else { return }
        store.add(milliliters: ml)
        customAmount = nil
    }

    // MARK: - Bas du menu

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Annuler le dernier ajout") {
                store.undoLast()
            }
            .disabled(!store.canUndo)
            Spacer()
            Button("Réglages…") {
                SettingsWindowController.shared.show(settings: store.settings)
            }
            Button("Quitter") {
                NSApp.terminate(nil)
            }
        }
        .buttonStyle(.borderless)
    }
}
