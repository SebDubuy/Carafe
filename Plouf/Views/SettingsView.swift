import SwiftUI

// MARK: - Onglet Général

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Objectif quotidien") {
                Picker("Calcul", selection: $settings.goalMode) {
                    Text("Fixe").tag(GoalMode.fixed)
                    Text("Selon mon poids").tag(GoalMode.weight)
                }
                .pickerStyle(.segmented)

                switch settings.goalMode {
                case .fixed:
                    Stepper(value: $settings.fixedGoalMilliliters,
                            in: AppSettings.fixedGoalRange,
                            step: AppSettings.fixedGoalStep) {
                        LabeledContent("Objectif", value: Formatters.liters(settings.fixedGoalMilliliters))
                    }
                case .weight:
                    Stepper(value: $settings.weightKilograms, in: AppSettings.weightRange) {
                        LabeledContent("Poids", value: "\(settings.weightKilograms) kg")
                    }
                    LabeledContent("Objectif calculé", value: Formatters.liters(settings.goalMilliliters))
                    Text("Poids × 33 ml, arrondi à 0,1 L.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Barre de menus") {
                Picker("Afficher", selection: $settings.menuBarDisplay) {
                    Text("Icône seule").tag(MenuBarDisplay.iconOnly)
                    Text("Icône + litres").tag(MenuBarDisplay.liters)
                    Text("Icône + pourcentage").tag(MenuBarDisplay.percent)
                }
            }

            Section {
                Toggle("Son à chaque verre", isOn: $settings.soundEnabled)
                Toggle("Lancer Plouf au démarrage", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        // On relit l'état réel : l'opération peut échouer ou demander une validation.
                        let actual = LaunchAtLogin.set(newValue)
                        if actual != newValue { launchAtLogin = actual }
                    }
            }
        }
        .waterFormStyle()
    }
}

// MARK: - Onglet Verres

struct GlassesSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Unité", selection: $settings.volumeUnit) {
                    Text("Centilitres (cl)").tag(VolumeUnit.centiliters)
                    Text("Millilitres (ml)").tag(VolumeUnit.milliliters)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("25 cl = 250 ml. Le total du jour reste affiché en litres.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach($settings.glasses) { $glass in
                    GlassRow(glass: $glass,
                             unit: settings.volumeUnit,
                             isDefault: settings.defaultGlassID == glass.id,
                             canDelete: settings.glasses.count > 1,
                             makeDefault: { settings.defaultGlassID = glass.id },
                             delete: { settings.removeGlass(id: glass.id) })
                }
            } header: {
                Text("Tailles de verre")
            } footer: {
                Text("De \(Formatters.glass(AppSettings.glassRange.lowerBound, unit: settings.volumeUnit)) à \(Formatters.glass(AppSettings.glassRange.upperBound, unit: settings.volumeUnit)). L'étoile marque le verre par défaut, proposé dans les notifications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                settings.addGlass()
            } label: {
                Label("Ajouter un verre", systemImage: "plus")
            }
        }
        .waterFormStyle()
    }
}

private struct GlassRow: View {
    @Binding var glass: GlassSize
    let unit: VolumeUnit
    let isDefault: Bool
    let canDelete: Bool
    let makeDefault: () -> Void
    let delete: () -> Void

    /// La quantité s'édite dans l'unité choisie (cl ou ml), mais reste stockée en ml.
    private var amount: Binding<Double> {
        Binding(
            get: { unit.value(fromMilliliters: glass.milliliters) },
            set: { glass.milliliters = min(max(unit.milliliters(from: $0), AppSettings.glassRange.lowerBound),
                                           AppSettings.glassRange.upperBound) }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: makeDefault) {
                Image(systemName: isDefault ? "star.fill" : "star")
                    .foregroundStyle(isDefault ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(Text("Verre par défaut"))

            // Titres vides + `prompt` : le texte gris s'affiche dans le champ,
            // pas comme une étiquette à côté (comportement par défaut dans un Form).
            TextField("", text: $glass.name, prompt: Text("Nom (facultatif)"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)

            TextField("", value: amount, format: .number.grouping(.never), prompt: Text(unit == .centiliters ? "25" : "250"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
            Text(unit.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)

            Button(action: delete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(canDelete ? Color.red : Color.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!canDelete)
            .help(Text("Supprimer ce verre"))
        }
    }
}
