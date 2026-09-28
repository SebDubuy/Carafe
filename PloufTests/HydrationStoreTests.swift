import XCTest
@testable import Plouf

@MainActor
final class HydrationStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var currentDate = Date()

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "PloufTests-\(UUID().uuidString)")
        currentDate = Date()
    }

    private func makeStore() -> HydrationStore {
        HydrationStore(settings: AppSettings(defaults: defaults),
                       persistence: Persistence(defaults: defaults),
                       now: { [unowned self] in currentDate })
    }

    func testAjoutEtProgression() {
        let store = makeStore()
        store.add(milliliters: 250)
        store.add(milliliters: 500)
        XCTAssertEqual(store.todayTotal, 750)
        XCTAssertEqual(store.progress, 0.375, accuracy: 0.0001)
        XCTAssertFalse(store.goalReached)
    }

    func testAnnulerRetireLeDernierVerre() {
        let store = makeStore()
        store.add(milliliters: 250)
        store.add(milliliters: 500)
        store.undoLast()
        XCTAssertEqual(store.todayTotal, 250)
    }

    func testAnnulerNeToucheJamaisAHier() {
        let store = makeStore()
        store.add(milliliters: 250)
        currentDate = currentDate.addingTimeInterval(24 * 3600)
        XCTAssertFalse(store.canUndo)
        store.undoLast()
        XCTAssertEqual(store.entries.count, 1)
    }

    func testPersistance() {
        makeStore().add(milliliters: 330)
        XCTAssertEqual(makeStore().todayTotal, 330)
    }

    func testPaliersIcone() {
        XCTAssertEqual(DropIconRenderer.level(for: 0), 0)
        XCTAssertEqual(DropIconRenderer.level(for: 0.01), 1)
        XCTAssertEqual(DropIconRenderer.level(for: 0.5), 5)
        XCTAssertEqual(DropIconRenderer.level(for: 0.99), 9)
        XCTAssertEqual(DropIconRenderer.level(for: 1.4), 10)
    }

    func testFormats() {
        XCTAssertEqual(Formatters.liters(1200), "1,2 L")
        XCTAssertEqual(Formatters.liters(2000), "2 L")
        XCTAssertEqual(Formatters.glass(250, unit: .centiliters), "25 cl")
        XCTAssertEqual(Formatters.glass(333, unit: .centiliters), "33,3 cl")
        XCTAssertEqual(Formatters.glass(5000, unit: .centiliters), "500 cl")
        XCTAssertEqual(Formatters.glass(250, unit: .milliliters), "250 ml")
        XCTAssertEqual(Formatters.glass(1500, unit: .milliliters), "1500 ml")
    }
}
