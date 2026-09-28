import XCTest
@testable import Plouf

final class ReminderEngineTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Paris")!
        return c
    }()

    /// Date du jour de test (28 septembre 2026) à l'heure indiquée.
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: hour, minute: minute))!
    }

    private func engine(_ configure: (inout ReminderConfig) -> Void = { _ in }) -> ReminderEngine {
        var config = ReminderConfig()
        configure(&config)
        return ReminderEngine(config: config, calendar: calendar)
    }

    private func input(_ now: Date, total: Int = 0, last: Date? = nil) -> ReminderInput {
        ReminderInput(now: now, todayTotal: total, goal: 2000, lastDrinkAt: last)
    }

    // MARK: - Inactivité

    func testInactiviteApres1h30SansBoire() {
        let e = engine { $0.paceEnabled = false }
        XCTAssertNil(e.evaluate(input(at(11, 0), total: 500, last: at(9, 45)), state: .init()).due)
        XCTAssertEqual(e.evaluate(input(at(11, 15), total: 500, last: at(9, 45)), state: .init()).due, .inactivity)
    }

    func testLeCompteAReboursRepartAChaqueVerre() {
        let e = engine { $0.paceEnabled = false }
        let d = e.evaluate(input(at(11, 15), total: 750, last: at(11, 0)), state: .init())
        XCTAssertNil(d.due)
        XCTAssertEqual(d.nextDate, at(12, 30))
    }

    func testPasDeRappelEnDehorsDeLaPlage() {
        let e = engine()
        XCTAssertNil(e.evaluate(input(at(8, 30)), state: .init()).due)
        XCTAssertEqual(e.evaluate(input(at(8, 30)), state: .init()).nextDate, at(9, 0))
        XCTAssertNil(e.evaluate(input(at(19, 30), total: 100), state: .init()).due)
    }

    func testPlusDeRappelUneFoisLObjectifAtteint() {
        let d = engine().evaluate(input(at(15, 0), total: 2000, last: at(9, 0)), state: .init())
        XCTAssertNil(d.due)
        XCTAssertNil(d.nextDate)
    }

    func testApresUnRappelOnAttendUnNouveauDelai() {
        let e = engine { $0.paceEnabled = false }
        let state = e.stateAfterSending(.inactivity, at: at(11, 15), from: .init())
        let d = e.evaluate(input(at(11, 20), total: 500, last: at(9, 45)), state: state)
        XCTAssertNil(d.due)
        XCTAssertEqual(d.nextDate, at(12, 45))
    }

    // MARK: - Rythme

    func testRythmeEnRetardDePlusDe20Pourcent() {
        // À 15 h : 60 % de la plage 9 h – 19 h écoulée → 1,2 L attendus. 0,8 L bu = 33 % de retard.
        let d = engine { $0.inactivityEnabled = false }
            .evaluate(input(at(15, 0), total: 800, last: at(14, 50)), state: .init())
        XCTAssertEqual(d.due, .pace(drunk: 800, expected: 1200))
    }

    func testRythmeLegerRetardToleré() {
        // 1 L bu pour 1,2 L attendus : 17 % de retard, sous le seuil.
        let d = engine { $0.inactivityEnabled = false }
            .evaluate(input(at(15, 0), total: 1000, last: at(14, 50)), state: .init())
        XCTAssertNil(d.due)
    }

    func testRythmeAuPlusUneFoisParHeure() {
        let e = engine { $0.inactivityEnabled = false }
        let state = e.stateAfterSending(.pace(drunk: 800, expected: 1200), at: at(15, 0), from: .init())
        XCTAssertNil(e.evaluate(input(at(15, 30), total: 800, last: at(14, 50)), state: state).due)
        XCTAssertNotNil(e.evaluate(input(at(16, 0), total: 800, last: at(14, 50)), state: state).due)
    }

    // MARK: - Rappel reporté

    func testRappelReporteDe15Minutes() {
        let e = engine()
        let state = e.stateAfterSnooze(at: at(11, 15), from: .init())
        XCTAssertNil(e.evaluate(input(at(11, 20), total: 500, last: at(9, 45)), state: state).due)
        XCTAssertEqual(e.evaluate(input(at(11, 30), total: 500, last: at(9, 45)), state: state).due, .snooze)
    }

    func testRappelReporteAnnuleSiOnABu() {
        let e = engine { $0.paceEnabled = false }
        let state = e.stateAfterSnooze(at: at(11, 15), from: .init())
        XCTAssertNil(e.evaluate(input(at(11, 30), total: 750, last: at(11, 20)), state: state).due)
    }

    func testFormatDesDurees() {
        XCTAssertEqual(Formatters.duration(minutes: 45), "45 min")
        XCTAssertEqual(Formatters.duration(minutes: 60), "1 h")
        XCTAssertEqual(Formatters.duration(minutes: 90), "1 h 30")
    }
}
