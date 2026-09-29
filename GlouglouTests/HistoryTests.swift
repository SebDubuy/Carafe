import XCTest
@testable import Glouglou

@MainActor
final class HistoryTests: XCTestCase {
    private var defaults: UserDefaults!
    private var currentDate = Date()
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Paris")!
        return c
    }()

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "GlouglouTests-\(UUID().uuidString)")
        currentDate = at(day: 28, hour: 10)
    }

    private func at(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private func makeStore() -> HydrationStore {
        HydrationStore(settings: AppSettings(defaults: defaults),
                       persistence: Persistence(defaults: defaults),
                       calendar: calendar,
                       now: { [unowned self] in currentDate })
    }

    func testRemiseAZeroAMinuitEtHistoriqueConserve() {
        let store = makeStore()
        store.add(milliliters: 1500)
        currentDate = at(day: 28, hour: 23, minute: 59)
        XCTAssertEqual(store.todayTotal, 1500)
        currentDate = at(day: 29, hour: 0, minute: 1)
        store.refreshDay()
        XCTAssertEqual(store.currentDay, calendar.startOfDay(for: currentDate))
        XCTAssertEqual(store.todayTotal, 0)
        XCTAssertEqual(store.history(days: 2).map(\.total), [1500, 0])
    }

    func testChangementDeJourApresPlusieursJoursEteint() {
        let store = makeStore()
        store.add(milliliters: 500)
        currentDate = at(day: 30, hour: 9)
        store.refreshDay()
        XCTAssertEqual(store.todayTotal, 0)
        XCTAssertEqual(store.history(days: 3).map(\.total), [500, 0, 0])
    }

    func testHistoriqueDeSeptJoursDuPlusAncienAAujourdHui() {
        let store = makeStore()
        let history = store.history(days: 7)
        XCTAssertEqual(history.count, 7)
        XCTAssertEqual(history.last?.day, calendar.startOfDay(for: currentDate))
        XCTAssertEqual(history.first?.day, calendar.startOfDay(for: at(day: 22, hour: 10)))
    }

    func testSerieDeJours() {
        let store = makeStore()
        for day in 25...27 {
            currentDate = at(day: day, hour: 12)
            store.add(milliliters: 2000)
        }
        currentDate = at(day: 28, hour: 10)
        // Aujourd'hui pas encore atteint : la série court jusqu'à hier.
        XCTAssertEqual(store.streak, 3)
        store.add(milliliters: 2000)
        XCTAssertEqual(store.streak, 4)
    }

    func testSerieCasseeParUnJourRate() {
        let store = makeStore()
        currentDate = at(day: 25, hour: 12); store.add(milliliters: 2000)
        currentDate = at(day: 26, hour: 12); store.add(milliliters: 500)
        currentDate = at(day: 27, hour: 12); store.add(milliliters: 2000)
        currentDate = at(day: 28, hour: 10)
        XCTAssertEqual(store.streak, 1)
    }

    func testObjectifRetenuParJour() {
        let store = makeStore()
        currentDate = at(day: 27, hour: 12)
        store.add(milliliters: 1500)
        store.settings.fixedGoalMilliliters = 1500
        let expectation = expectation(description: "objectif enregistré")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)
        currentDate = at(day: 28, hour: 10)
        store.settings.fixedGoalMilliliters = 3000
        // Hier : objectif de 1,5 L atteint, même si l'objectif est passé à 3 L depuis.
        XCTAssertTrue(store.history(days: 2).first!.goalReached)
    }

    func testSupprimerUnVerrePrecis() {
        let store = makeStore()
        store.add(milliliters: 250)
        store.add(milliliters: 500)
        store.add(milliliters: 330)
        store.delete(id: store.todayEntries[1].id)
        XCTAssertEqual(store.todayEntries.map(\.milliliters), [250, 330])
    }

    func testSimulationDuJourSuivantEnDebug() {
        let store = makeStore()
        store.add(milliliters: 750)
        store.debugNextDay()
        XCTAssertEqual(store.todayTotal, 0)
        store.add(milliliters: 250)
        store.debugBackToToday()
        XCTAssertEqual(store.todayTotal, 750)
        XCTAssertEqual(store.entries.count, 1)
    }

    func testEtatAlerteApresLeDelaiDInactivite() {
        let engine = ReminderEngine(config: ReminderConfig(), calendar: calendar)
        let base = ReminderInput(now: at(day: 28, hour: 11, minute: 20), todayTotal: 500, goal: 2000,
                                 lastDrinkAt: at(day: 28, hour: 9, minute: 45))
        XCTAssertTrue(engine.isInactive(base))
        var recent = base
        recent.lastDrinkAt = at(day: 28, hour: 11)
        XCTAssertFalse(engine.isInactive(recent))
        var evening = base
        evening.now = at(day: 28, hour: 20)
        XCTAssertFalse(engine.isInactive(evening))
    }

    func testStatistiques() {
        let store = makeStore()
        XCTAssertNil(store.weeklyAverage)
        currentDate = at(day: 25, hour: 10); store.add(milliliters: 1500)
        currentDate = at(day: 26, hour: 10); store.add(milliliters: 2500)
        currentDate = at(day: 27, hour: 15); store.add(milliliters: 500)
        currentDate = at(day: 28, hour: 10); store.add(milliliters: 3000)
        // Moyenne des jours précédents notés (aujourd'hui exclu) : (1,5 + 2,5 + 0,5) / 3 = 1,5 L
        XCTAssertEqual(store.weeklyAverage, 1500)
        XCTAssertEqual(store.bestDay?.total, 3000)
        XCTAssertEqual(store.peakHour, 10)
    }

    func testTempsEcoule() {
        let now = at(day: 28, hour: 12)
        XCTAssertEqual(Formatters.elapsed(since: now, now: now), "à l'instant")
        XCTAssertEqual(Formatters.elapsed(since: at(day: 28, hour: 11, minute: 15), now: now), "il y a 45 min")
        XCTAssertEqual(Formatters.elapsed(since: at(day: 28, hour: 10, minute: 40), now: now), "il y a 1 h 20")
    }
}
