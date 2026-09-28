import SwiftUI

/// Fenêtre des réglages, en onglets.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem { Label("Général", systemImage: "gearshape") }
            GlassesSettingsView(settings: settings)
                .tabItem { Label("Verres", systemImage: "cup.and.saucer") }
        }
        .frame(width: 460, height: 400)
    }
}

// MARK: - Onglet Général

private struct GeneralSettingsView: View {
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
        .formStyle(.grouped)
    }
}

// MARK: - Onglet Verres

private struct GlassesSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                ForEach($settings.glasses) { $glass in
                    GlassRow(glass: $glass,
                             isDefault: settings.defaultGlassID == glass.id,
                             canDelete: settings.glasses.count > 1,
                             makeDefault: { settings.defaultGlassID = glass.id },
                             delete: { settings.removeGlass(id: glass.id) })
                }
            } header: {
                Text("Tailles de verre")
            } footer: {
                Text("L'étoile marque le verre par défaut, proposé dans les notifications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                settings.addGlass()
            } label: {
                Label("Ajouter un verre", systemImage: "plus")
            }
        }
        .formStyle(.grouped)
    }
}

private struct GlassRow: View {
    @Binding var glass: GlassSize
    let isDefault: Bool
    let canDelete: Bool
    let makeDefault: () -> Void
    let delete: () -> Void

    /// La quantité s'édite en centilitres.
    private var centiliters: Binding<Int> {
        Binding(
            get: { glass.milliliters / 10 },
            set: { glass.milliliters = min(max($0 * 10, AppSettings.glassRange.lowerBound),
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

            TextField("Nom (facultatif)", text: $glass.name)
                .textFieldStyle(.roundedBorder)

            TextField("cl", value: centiliters, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
            Text("cl")
                .foregroundStyle(.secondary)

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
