import SwiftUI

/// Fenêtre des réglages : onglets maison en haut, puis cartes en verre sur un fond bleu uniforme.
/// Tout est dessiné en SwiftUI (pas de barre d'outils ni de `Form` système) pour que
/// le fond soit le même partout, comme dans le menu.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var scheduler: ReminderScheduler

    private enum Tab: Hashable {
        case general
        case glasses
        case reminders
        case debug
    }

    @State private var tab: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.top, 34)   // place pour les boutons rouge / orange / vert
                .padding(.bottom, 10)

            ScrollView {
                Group {
                    switch tab {
                    case .general:
                        GeneralSettingsView(settings: settings)
                    case .glasses:
                        GlassesSettingsView(settings: settings)
                    case .reminders:
                        RemindersSettingsView(settings: settings, scheduler: scheduler,
                                              notifications: scheduler.notifications)
                    case .debug:
                        DebugView(settings: settings, scheduler: scheduler, store: scheduler.storeForUI)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 460, height: 540)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            TabButton(title: "Général", isSelected: tab == .general) {
                Image(systemName: "gearshape")
            } action: { tab = .general }
            TabButton(title: "Verres", isSelected: tab == .glasses) {
                // Image dessinée en code : on l'agrandit à la taille des symboles système.
                Image(nsImage: DropIconRenderer.templateDrop)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
            } action: { tab = .glasses }
            TabButton(title: "Rappels", isSelected: tab == .reminders) {
                Image(systemName: "bell")
            } action: { tab = .reminders }
            if settings.debugMode {
                TabButton(title: "Debug", isSelected: tab == .debug) {
                    Image(systemName: "ladybug")
                } action: { tab = .debug }
            }
        }
    }
}

/// Bouton d'onglet : icône + titre, sur une pastille bleutée quand il est sélectionné.
private struct TabButton<Icon: View>: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    @ViewBuilder let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                icon
                    .font(.system(size: 17))
                    .frame(height: 20)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .frame(width: 72, height: 50)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.10))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Éléments communs

/// Carte en verre qui regroupe des réglages, avec un titre au-dessus.
struct GlassCard<Content: View>: View {
    let title: LocalizedStringKey?
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
        }
    }
}

/// Petite note grise sous un réglage.
struct Caption: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Onglet Général

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard("Objectif quotidien") {
                Picker("Calcul", selection: $settings.goalMode) {
                    Text("Fixe").tag(GoalMode.fixed)
                    Text("Selon mon poids").tag(GoalMode.weight)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch settings.goalMode {
                case .fixed:
                    HStack {
                        Text("Objectif")
                        Spacer()
                        Text(Formatters.liters(settings.fixedGoalMilliliters))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                        Stepper("", value: $settings.fixedGoalMilliliters,
                                in: AppSettings.fixedGoalRange,
                                step: AppSettings.fixedGoalStep)
                            .labelsHidden()
                    }
                case .weight:
                    HStack {
                        Text("Poids")
                        Spacer()
                        Text("\(settings.weightKilograms) kg")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                        Stepper("", value: $settings.weightKilograms, in: AppSettings.weightRange)
                            .labelsHidden()
                    }
                    HStack {
                        Text("Objectif calculé")
                        Spacer()
                        Text(Formatters.liters(settings.goalMilliliters))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.waterLight)
                    }
                    Caption("Poids × 33 ml, arrondi à 0,1 L.")
                }
            }

            GlassCard("Barre de menus") {
                HStack {
                    Text("Afficher")
                    Spacer()
                    Picker("Afficher", selection: $settings.menuBarDisplay) {
                        Text("Icône seule").tag(MenuBarDisplay.iconOnly)
                        Text("Icône + litres").tag(MenuBarDisplay.liters)
                        Text("Icône + pourcentage").tag(MenuBarDisplay.percent)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            GlassCard("Divers") {
                HStack {
                    Text("Son à chaque verre")
                    Spacer()
                    Toggle("Son à chaque verre", isOn: $settings.soundEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                HStack {
                    Text("Lancer Carafe au démarrage")
                    Spacer()
                    Toggle("Lancer Carafe au démarrage", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { newValue in
                            // On relit l'état réel : l'opération peut échouer ou demander une validation.
                            let actual = LaunchAtLogin.set(newValue)
                            if actual != newValue { launchAtLogin = actual }
                        }
                }
            }
        }
    }
}

// MARK: - Onglet Verres

struct GlassesSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard("Unité") {
                Picker("Unité", selection: $settings.volumeUnit) {
                    Text("Centilitres (cl)").tag(VolumeUnit.centiliters)
                    Text("Millilitres (ml)").tag(VolumeUnit.milliliters)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Caption("25 cl = 250 ml. Le total du jour reste affiché en litres.")
            }

            GlassCard("Tailles de verre") {
                ForEach($settings.glasses) { $glass in
                    GlassRow(glass: $glass,
                             unit: settings.volumeUnit,
                             isDefault: settings.defaultGlassID == glass.id,
                             canDelete: settings.glasses.count > 1,
                             makeDefault: { settings.defaultGlassID = glass.id },
                             delete: { settings.removeGlass(id: glass.id) })
                }

                Button {
                    settings.addGlass()
                } label: {
                    Label("Ajouter un verre", systemImage: "plus.circle.fill")
                        .foregroundStyle(Theme.waterLight)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                Caption("De \(Formatters.glass(AppSettings.glassRange.lowerBound, unit: settings.volumeUnit)) à \(Formatters.glass(AppSettings.glassRange.upperBound, unit: settings.volumeUnit)). L'étoile marque le verre par défaut, proposé dans les notifications.")
            }
        }
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

            // Titres vides + `prompt` : le texte gris s'affiche dans le champ.
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
