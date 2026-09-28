import Foundation

/// Formats d'affichage des quantités : virgule décimale, « cl » et « L ».
enum Formatters {
    /// Locale utilisée pour les nombres (virgule décimale).
    static var locale = Locale(identifier: "fr_FR")

    /// 1200 → « 1,2 », 2000 → « 2 », 1250 → « 1,25 »
    static func litersValue(_ milliliters: Int, maxFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: Double(milliliters) / 1000)) ?? ""
    }

    /// 1200 → « 1,2 L »
    static func liters(_ milliliters: Int) -> String {
        "\(litersValue(milliliters)) L"
    }

    /// Quantité de verre : en cl si ça tombe juste (250 → « 25 cl »), sinon en ml.
    static func glass(_ milliliters: Int) -> String {
        milliliters % 10 == 0 ? "\(milliliters / 10) cl" : "\(milliliters) ml"
    }

    /// 0.6 → « 60 % » (espace fine insécable avant le signe, à la française)
    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))\u{202F}%"
    }
}
