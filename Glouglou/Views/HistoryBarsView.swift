import SwiftUI

/// Mini historique des 7 derniers jours : une petite barre par jour, remplie selon
/// la quantité bue ; une goutte au-dessus quand l'objectif a été atteint.
struct HistoryBarsView: View {
    let days: [DaySummary]

    private static let barHeight: CGFloat = 38

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                let isToday = index == days.count - 1
                VStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.waterLight)
                        .opacity(day.goalReached ? 1 : 0)
                    ZStack(alignment: .bottom) {
                        Capsule()
                            .fill(Color.primary.opacity(0.10))
                        Capsule()
                            .fill(day.goalReached ? AnyShapeStyle(Theme.waterGradient)
                                                  : AnyShapeStyle(Theme.water.opacity(0.6)))
                            .frame(height: max(Self.barHeight * day.progress, day.total > 0 ? 4 : 0))
                    }
                    .frame(width: 16, height: Self.barHeight)
                    Text(Self.weekdayLetter(day.day))
                        .font(.caption2.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .help(Text("\(Self.dayName(day.day)) : \(Formatters.liters(day.total)) sur \(Formatters.liters(day.goal))"))
            }
        }
    }

    /// « L », « M », « M », « J »…
    private static func weekdayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Formatters.locale
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date).uppercased()
    }

    /// « lundi 28 sept. »
    private static func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Formatters.locale
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMM")
        return formatter.string(from: date)
    }
}
