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

    /// Contenance d'un verre dans l'unité choisie : 250 → « 25 cl » ou « 250 ml », 333 → « 33,3 cl ».
    static func glass(_ milliliters: Int, unit: VolumeUnit) -> String {
        "\(number(unit.value(fromMilliliters: milliliters), maxFractionDigits: 1)) \(unit.symbol)"
    }

    /// Nombre avec virgule décimale, sans zéros inutiles.
    static func number(_ value: Double, maxFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }

    /// Durée : 45 → « 45 min », 60 → « 1 h », 90 → « 1 h 30 »
    static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) h"
        default: return "\(hours) h \(String(format: "%02d", rest))"
        }
    }

    /// 0.6 → « 60 % » (espace fine insécable avant le signe, à la française)
    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))\u{202F}%"
    }
}
