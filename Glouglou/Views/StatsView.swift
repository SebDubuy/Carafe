import SwiftUI

/// Trois petites tuiles sous l'historique : moyenne de la semaine, meilleure journée,
/// heure où l'on boit le plus.
struct StatsView: View {
    @ObservedObject var store: HydrationStore

    var body: some View {
        HStack(spacing: 8) {
            tile(title: "Moyenne 7 j",
                 value: store.weeklyAverage.map(Formatters.liters) ?? "—",
                 detail: nil)
            tile(title: "Record",
                 value: store.bestDay.map { Formatters.liters($0.total) } ?? "—",
                 detail: store.bestDay.map { Self.shortDay($0.day) })
            tile(title: "Pic",
                 value: store.peakHour.map { "\($0) h" } ?? "—",
                 detail: store.peakHour.map { "\($0) h – \(($0 + 1) % 24) h" })
        }
    }

    private func tile(title: LocalizedStringKey, value: String, detail: String?) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text(detail ?? " ")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.06)))
    }

    /// « mar. 22 »
    private static func shortDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Formatters.locale
        formatter.setLocalizedDateFormatFromTemplate("EEE d")
        return formatter.string(from: date)
    }
}
