import XCTest

final class SunCalcTests: XCTestCase {
    private var parisCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    /// Ajaccio (41,92 N / 8,74 E) au solstice d'été : valeurs connues à quelques
    /// minutes près (l'algorithme NOAA vise ~1 min de précision).
    func testSummerSolsticeAjaccio() {
        let calendar = parisCalendar
        let noonUTC = DateComponents(calendar: calendar, year: 2026, month: 6, day: 21, hour: 14).date!
        let sun = SunCalc.compute(at: noonUTC, latitude: 41.92, longitude: 8.74, calendar: calendar)

        // Durée du jour ≈ 15 h 05 au solstice à cette latitude.
        XCTAssertEqual(sun.daylight / 3600, 15.08, accuracy: 0.5)
        // Élévation max = 90 − |lat − déclinaison| ≈ 71,5°.
        XCTAssertEqual(sun.maxElevation, 71.5, accuracy: 1.0)
        // Midi solaire vers 13 h 27 heure locale (CEST).
        let noonComponents = calendar.dateComponents([.hour, .minute], from: sun.solarNoon)
        let noonMinutes = Double((noonComponents.hour ?? 0) * 60 + (noonComponents.minute ?? 0))
        XCTAssertEqual(noonMinutes, Double(13 * 60 + 27), accuracy: 12)
        XCTAssertNotNil(sun.sunrise)
        XCTAssertNotNil(sun.sunset)
    }

    func testPolarNightHasNoSunrise() {
        let calendar = parisCalendar
        let date = DateComponents(calendar: calendar, year: 2026, month: 12, day: 21, hour: 12).date!
        let sun = SunCalc.compute(at: date, latitude: 78.22, longitude: 15.63, calendar: calendar)
        XCTAssertNil(sun.sunrise)
        XCTAssertNil(sun.sunset)
        XCTAssertEqual(sun.daylight, 0)
        XCTAssertLessThan(sun.elevation, 0)
    }

    func testElevationIsNegativeAtNight() {
        let calendar = parisCalendar
        let midnight = DateComponents(calendar: calendar, year: 2026, month: 8, day: 5, hour: 1).date!
        let sun = SunCalc.compute(at: midnight, latitude: 42.15, longitude: 9.08, calendar: calendar)
        XCTAssertLessThan(sun.elevation, 0)
    }
}
