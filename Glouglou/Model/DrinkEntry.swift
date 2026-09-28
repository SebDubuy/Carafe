import Foundation

/// Un verre bu : une quantité en millilitres à un instant donné.
struct DrinkEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let milliliters: Int
    let date: Date

    init(id: UUID = UUID(), milliliters: Int, date: Date = Date()) {
        self.id = id
        self.milliliters = milliliters
        self.date = date
    }
}
