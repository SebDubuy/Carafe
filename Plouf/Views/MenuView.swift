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
            undoRow
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
        .background(Theme.menuBackground)
    }

    // MARK: - Progression du jour

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(Theme.waterGradient)
                Text("Aujourd'hui")
                    .font(.headline)
                Spacer()
                Text(Formatters.percent(Double(store.todayTotal) / Double(max(store.goalMilliliters, 1))))
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.water)
                    .monospacedDigit()
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Formatters.litersValue(store.todayTotal)) L")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.waterGradient)
                Text("sur \(Formatters.liters(store.goalMilliliters))")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            WaterProgressBar(progress: store.progress)
            if store.goalReached {
                Text("Objectif atteint, bravo !")
                    .font(.callout)
                    .foregroundStyle(Theme.water)
            }
        }
    }

    // MARK: - Ajout rapide

    private var addButtons: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(store.settings.glasses) { glass in
                Button {
                    add(glass.milliliters)
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
                }
                .buttonStyle(WaterButtonStyle())
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
                .buttonStyle(.borderedProminent)
                .tint(Theme.water)
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
        add(ml)
        customAmount = nil
    }

    /// Ajoute un verre et joue le « plouf » si le son est activé.
    private func add(_ milliliters: Int) {
        store.add(milliliters: milliliters)
        SoundPlayer.playPlouf(if: store.settings.soundEnabled)
    }

    // MARK: - Annulation

    private var undoRow: some View {
        Button {
            store.undoLast()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(Theme.water)
                Text("Annuler le dernier ajout")
                if let last = store.todayEntries.last {
                    Text("(\(Formatters.glass(last.milliliters, unit: unit)))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .disabled(!store.canUndo)
    }

    // MARK: - Bas du menu

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Réglages…") {
                SettingsWindowController.shared.show(settings: store.settings)
            }
            Spacer()
            Button("Quitter") {
                NSApp.terminate(nil)
            }
        }
        .buttonStyle(.borderless)
    }
}
