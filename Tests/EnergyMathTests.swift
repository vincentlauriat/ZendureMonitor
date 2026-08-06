import XCTest

final class EnergyMathTests: XCTestCase {

    // MARK: - solarToBattery

    func testSolarCoversCharge() {
        XCTAssertEqual(EnergyMath.solarToBattery(solar: 800, charge: 300, gridIn: 0), 300)
    }

    func testGridChargeExcluded() {
        // Charge AC heures creuses, la nuit : rien ne vient du solaire.
        XCTAssertEqual(EnergyMath.solarToBattery(solar: 0, charge: 1200, gridIn: 1200), 0)
    }

    func testMixedChargePartlySolar() {
        XCTAssertEqual(EnergyMath.solarToBattery(solar: 500, charge: 700, gridIn: 300), 400)
    }

    func testChargeCappedBySolar() {
        XCTAssertEqual(EnergyMath.solarToBattery(solar: 200, charge: 700, gridIn: 0), 200)
    }

    func testNoCharge() {
        XCTAssertEqual(EnergyMath.solarToBattery(solar: 900, charge: 0, gridIn: 0), 0)
    }

    func testGridExceedsCharge() {
        // Bypass réseau → maison : la différence négative ne doit pas déborder.
        XCTAssertEqual(EnergyMath.solarToBattery(solar: 400, charge: 100, gridIn: 500), 0)
    }

    // MARK: - storedShare

    func testStoredShare() {
        XCTAssertEqual(EnergyMath.storedShare(storedWh: 250, solarWh: 1000), 0.25)
    }

    func testStoredShareNilWhenNoProduction() {
        XCTAssertNil(EnergyMath.storedShare(storedWh: 0, solarWh: 0.2))
    }

    func testStoredShareCappedAtOne() {
        XCTAssertEqual(EnergyMath.storedShare(storedWh: 1200, solarWh: 1000), 1)
    }
}
