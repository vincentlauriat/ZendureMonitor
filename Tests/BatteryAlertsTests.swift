import XCTest

final class BatteryAlertsTests: XCTestCase {
    func testLowFiresOncePerEpisodeAndRearmsAboveHysteresis() {
        var alerts = BatteryAlerts()
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 14, socMax: nil, lowThreshold: 15), [.low])
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 12, socMax: nil, lowThreshold: 15), [])
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 19, socMax: nil, lowThreshold: 15), [])
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 21, socMax: nil, lowThreshold: 15), [])
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 15, socMax: nil, lowThreshold: 15), [.low])
    }

    func testFullUsesDeviceCeilingAndRearmsBelowHysteresis() {
        var alerts = BatteryAlerts()
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 89.6, socMax: 90, lowThreshold: 15), [.full])
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 90, socMax: 90, lowThreshold: 15), [])
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 86, socMax: 90, lowThreshold: 15), [])
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 84, socMax: 90, lowThreshold: 15), [])
        // Réarmée sous 85 % : plafond inconnu → 100 %, l'alerte repart.
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 100, socMax: nil, lowThreshold: 15), [.full])
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 100, socMax: 90, lowThreshold: 15), [])
    }

    /// Le cas qui motive le « par appareil » : un SolarFlow vide pendant
    /// que l'autre est plein — la moyenne (55 %) n'alerterait jamais.
    func testDevicesAreIndependent() {
        var alerts = BatteryAlerts()
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 10, socMax: 100, lowThreshold: 15), [.low])
        XCTAssertEqual(alerts.evaluate(id: "B", soc: 100, socMax: 100, lowThreshold: 15), [.full])
        XCTAssertEqual(alerts.evaluate(id: "B", soc: 8, socMax: 100, lowThreshold: 15), [.low])
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 9, socMax: 100, lowThreshold: 15), [])
    }

    func testForgetDropsRemovedDevices() {
        var alerts = BatteryAlerts()
        _ = alerts.evaluate(id: "A", soc: 10, socMax: nil, lowThreshold: 15)
        alerts.keep(ids: ["B"])
        XCTAssertEqual(alerts.evaluate(id: "A", soc: 10, socMax: nil, lowThreshold: 15), [.low])
    }
}
