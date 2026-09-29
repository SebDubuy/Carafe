import SwiftUI

/// Contenu de la fenêtre qui s'ouvre au clic sur l'icône.
struct MenuView: View {
    @ObservedObject var store: HydrationStore
    @ObservedObject var scheduler: ReminderScheduler
    @Environment(\.colorScheme) private var colorScheme
    /// Quantité libre saisie, dans l'unité choisie (cl ou ml).
    @State private var customAmount: Double?
    /// Liste des verres du jour dépliée ou non.
    @State private var showTodayList = false
    /// Incrémenté quand l'objectif vient d'être atteint : déclenche l'éclaboussure.
    @State private var splashCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            progressSection
            addButtons
            customAmountRow
            todaySection
            Divider()
            historySection
            NotificationsWarning(notifications: scheduler.notifications)
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
        .overlay(alignment: .top) {
            SplashView(trigger: splashCount)
                .padding(.top, 60)
        }
        .background(Theme.surface.ignoresSafeArea())
        .preferredColorScheme(.light)

    }

    // MARK: - Progression du jour

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                // Même goutte que dans la barre de menus, remplie selon la progression.
                Image(nsImage: DropIconRenderer.image(progress: store.progress,
                                                      darkMenuBar: colorScheme == .dark,
                                                      alert: scheduler.isInactive))
                Text("Aujourd'hui")
                    .font(.title3.weight(.bold))
                Spacer()
                Text(Formatters.percent(Double(store.todayTotal) / Double(max(store.goalMilliliters, 1))))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Formatters.litersValue(store.todayTotal)) L")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("sur \(Formatters.liters(store.goalMilliliters))")
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            WaterProgressBar(progress: store.progress)
            if store.goalReached {
                Text("Objectif atteint, bravo ! 🎉")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
            }
            infoLine
        }
    }

    /// « Dernier verre il y a 45 min » et la série de jours.
    private var infoLine: some View {
        HStack(spacing: 8) {
            // Rafraîchi chaque minute pour que « il y a… » reste juste.
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                Text(lastDrinkText)
                    .foregroundStyle(scheduler.isInactive ? Color.orange : Color.secondary)
            }
            Spacer()
            if store.streak >= 2 {
                Text("🔥 \(store.streak) jours d'affilée")
                    .foregroundStyle(.primary)
            }
        }
        .font(.callout)
    }

    private var lastDrinkText: String {
        guard let last = store.lastDrinkToday else {
            return String(localized: "Pas encore de verre aujourd'hui")
        }
        return String(localized: "Dernier verre \(Formatters.elapsed(since: last, now: store.now))")
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
                            .font(.body.weight(.medium))
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
                .buttonStyle(.bordered)
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

    /// Ajoute un verre et joue le petit son si le son est activé.
    /// Si ce verre fait atteindre l'objectif du jour : éclaboussure !
    private func add(_ milliliters: Int) {
        let wasReached = store.goalReached
        store.add(milliliters: milliliters)
        if !wasReached && store.goalReached {
            splashCount += 1
        }
        SoundPlayer.playDrinkSound(if: store.settings.soundEnabled)
    }

    // MARK: - Verres du jour

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                undoRow
                Spacer()
                if !store.todayEntries.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showTodayList.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Verres du jour (\(store.todayEntries.count))")
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(showTodayList ? 180 : 0))
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.callout)
                }
            }
            if showTodayList && !store.todayEntries.isEmpty {
                VStack(spacing: 4) {
                    // Du plus récent au plus ancien.
                    ForEach(store.todayEntries.reversed()) { entry in
                        HStack {
                            Text(entry.date.formatted(date: .omitted, time: .shortened))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Text(Formatters.glass(entry.milliliters, unit: unit))
                            Spacer()
                            Button {
                                store.delete(id: entry.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help(Text("Supprimer ce verre"))
                        }
                        .font(.callout)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06)))
            }
        }
    }

    // MARK: - Historique

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7 derniers jours")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HistoryBarsView(days: store.history(days: 7))
        }
    }

    // MARK: - Annulation

    private var undoRow: some View {
        Button {
            store.undoLast()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                Text("Annuler")
                if let last = store.todayEntries.last {
                    Text("(\(Formatters.glass(last.milliliters, unit: unit)))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .disabled(!store.canUndo)
        .help(Text("Annuler le dernier ajout"))
    }

    // MARK: - Bas du menu

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Réglages…") {
                // Option + clic : mode debug caché.
                if NSEvent.modifierFlags.contains(.option) {
                    store.settings.debugMode = true
                }
                SettingsWindowController.shared.show(scheduler: scheduler)
            }
            Spacer()
            Button("Quitter") {
                NSApp.terminate(nil)
            }
        }
        .buttonStyle(.borderless)
    }
}

/// Avertissement discret quand macOS bloque les notifications de Carafe :
/// sans ça, les rappels partent mais ne s'affichent jamais.
private struct NotificationsWarning: View {
    @ObservedObject var notifications: NotificationManager

    var body: some View {
        if notifications.authorization == .denied {
            Button {
                NotificationManager.openSystemSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(.orange)
                    Text("Notifications bloquées : les autoriser…")
                }
            }
            .buttonStyle(.borderless)
            .font(.callout)
            .help(Text("Réglages Système › Notifications › Carafe"))
        }
    }
}
