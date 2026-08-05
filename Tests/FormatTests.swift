import XCTest

final class FormatTests: XCTestCase {
    func testWatts() {
        XCTAssertEqual(Format.watts(0), "0 W")
        XCTAssertEqual(Format.watts(849.6), "850 W")
        // Le séparateur décimal dépend de la locale : comparer à la même mise en forme.
        XCTAssertEqual(Format.watts(1500), String(format: "%.2f kW", locale: .current, 1.5))
        XCTAssertEqual(Format.wattsCompact(1500), String(format: "%.1f kW", locale: .current, 1.5))
    }

    func testKilowattHours() {
        XCTAssertEqual(Format.kilowattHours(999), "999 Wh")
        XCTAssertEqual(Format.kilowattHours(2526.7), String(format: "%.2f kWh", locale: .current, 2.5267))
    }

    func testDuration() {
        XCTAssertEqual(Format.duration(minutes: 45), "45 min")
        XCTAssertEqual(Format.duration(minutes: 125), "2 h 05")
    }
}
