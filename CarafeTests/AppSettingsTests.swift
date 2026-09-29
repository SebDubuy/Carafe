import XCTest
@testable import Carafe

@MainActor
final class AppSettingsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "CarafeTests-\(UUID().uuidString)")
    }

    func testValeursParDefaut() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.goalMilliliters, 2000)
        XCTAssertEqual(settings.glasses.map(\.milliliters), [150, 250, 330, 500])
        XCTAssertEqual(settings.defaultGlass?.milliliters, 250)
        XCTAssertEqual(settings.menuBarDisplay, .iconOnly)
    }

    func testObjectifSelonLePoids() {
        // 70 kg × 33 ml = 2310 ml → 2,3 L ; 75 kg → 2475 ml → 2,5 L
        XCTAssertEqual(AppSettings.goalFromWeight(70), 2300)
        XCTAssertEqual(AppSettings.goalFromWeight(75), 2500)
        let settings = AppSettings(defaults: defaults)
        settings.goalMode = .weight
        settings.weightKilograms = 60
        XCTAssertEqual(settings.goalMilliliters, 2000)
    }

    func testReglagesConservesApresRelance() {
        let settings = AppSettings(defaults: defaults)
        settings.fixedGoalMilliliters = 2750
        settings.menuBarDisplay = .percent
        settings.glasses[0].name = "Ma gourde"
        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.fixedGoalMilliliters, 2750)
        XCTAssertEqual(reloaded.menuBarDisplay, .percent)
        XCTAssertEqual(reloaded.glasses[0].name, "Ma gourde")
    }

    func testOnGardeToujoursUnVerre() {
        let settings = AppSettings(defaults: defaults)
        for glass in settings.glasses { settings.removeGlass(id: glass.id) }
        XCTAssertEqual(settings.glasses.count, 1)
        XCTAssertEqual(settings.defaultGlassID, settings.glasses.first?.id)
    }

    func testConversionUnites() {
        XCTAssertEqual(VolumeUnit.centiliters.milliliters(from: 50), 500)
        XCTAssertEqual(VolumeUnit.milliliters.milliliters(from: 500), 500)
        XCTAssertEqual(VolumeUnit.centiliters.value(fromMilliliters: 750), 75)
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.volumeUnit, .centiliters)
        settings.volumeUnit = .milliliters
        XCTAssertEqual(AppSettings(defaults: defaults).volumeUnit, .milliliters)
    }

    func testFormatBarreEnPourcentage() {
        XCTAssertEqual(Formatters.percent(0.6), "60\u{202F}%")
    }
}
