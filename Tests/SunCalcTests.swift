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

    /// La course échantillonnée doit coller aux éphémérides : l'apogée tombe au
    /// midi solaire et culmine à l'élévation maximale annoncée.
    func testTrackApexMatchesEphemeris() {
        let calendar = parisCalendar
        let date = DateComponents(calendar: calendar, year: 2026, month: 5, day: 12, hour: 12).date!
        let sun = SunCalc.compute(at: date, latitude: 42.15, longitude: 9.08, calendar: calendar)
        let track = SunCalc.track(on: date, latitude: 42.15, longitude: 9.08, calendar: calendar)

        XCTAssertEqual(track.count, 241)   // 24 h par pas de 6 min, bornes incluses
        let apex = track.max { $0.elevation < $1.elevation }
        XCTAssertNotNil(apex)
        XCTAssertEqual(apex!.elevation, sun.maxElevation, accuracy: 1.0)
        XCTAssertEqual(apex!.date.timeIntervalSince(sun.solarNoon), 0, accuracy: 360)
        // Le soleil se lève à l'est et se couche à l'ouest.
        let daylight = track.filter { $0.elevation > 0 }
        XCTAssertLessThan(daylight.first!.azimuth, 120)
        XCTAssertGreaterThan(daylight.last!.azimuth, 240)
    }

    /// Les crépuscules s'emboîtent : astronomique avant nautique avant civil
    /// avant le lever, et symétriquement le soir.
    func testTwilightsAreOrdered() {
        let calendar = parisCalendar
        let date = DateComponents(calendar: calendar, year: 2026, month: 9, day: 15, hour: 12).date!
        let sun = SunCalc.compute(at: date, latitude: 42.15, longitude: 9.08, calendar: calendar)
        let twilight = SunCalc.twilight(on: date, latitude: 42.15, longitude: 9.08, calendar: calendar)

        let morning = [twilight.astronomicalDawn, twilight.nauticalDawn, twilight.civilDawn,
                       sun.sunrise, twilight.goldenHourMorningEnd, sun.solarNoon]
        XCTAssertEqual(morning.compactMap { $0 }.count, morning.count)
        XCTAssertEqual(morning.compactMap { $0 }, morning.compactMap { $0 }.sorted())

        let evening = [sun.solarNoon, twilight.goldenHourEveningStart, sun.sunset,
                       twilight.civilDusk, twilight.nauticalDusk, twilight.astronomicalDusk]
        XCTAssertEqual(evening.compactMap { $0 }.count, evening.count)
        XCTAssertEqual(evening.compactMap { $0 }, evening.compactMap { $0 }.sorted())
    }

    /// Franchissement à −0,833° : on doit retrouver lever et coucher.
    func testCrossingsAtSunriseAltitudeMatchSunriseAndSunset() {
        let calendar = parisCalendar
        let date = DateComponents(calendar: calendar, year: 2026, month: 3, day: 3, hour: 12).date!
        let sun = SunCalc.compute(at: date, latitude: 48.85, longitude: 2.35, calendar: calendar)
        let crossings = SunCalc.crossings(atAltitude: -0.833, on: date,
                                          latitude: 48.85, longitude: 2.35, calendar: calendar)
        XCTAssertEqual(crossings.morning!.timeIntervalSince(sun.sunrise!), 0, accuracy: 1)
        XCTAssertEqual(crossings.evening!.timeIntervalSince(sun.sunset!), 0, accuracy: 1)
    }

    /// Équinoxe de printemps 2026 : 20 mars. Solstice d'été : 21 juin.
    func testNextSolarEventFindsEquinoxThenSolstice() {
        let calendar = parisCalendar
        let january = DateComponents(calendar: calendar, year: 2026, month: 1, day: 5, hour: 12).date!
        let equinox = SunCalc.nextSolarEvent(after: january)
        XCTAssertEqual(equinox?.kind, .springEquinox)
        XCTAssertEqual(calendar.component(.month, from: equinox!.date), 3)
        XCTAssertEqual(Double(calendar.component(.day, from: equinox!.date)), 20, accuracy: 1)

        let april = DateComponents(calendar: calendar, year: 2026, month: 4, day: 1, hour: 12).date!
        let solstice = SunCalc.nextSolarEvent(after: april)
        XCTAssertEqual(solstice?.kind, .summerSolstice)
        XCTAssertEqual(calendar.component(.month, from: solstice!.date), 6)
        XCTAssertEqual(Double(calendar.component(.day, from: solstice!.date)), 21, accuracy: 1)
    }

    func testElevationIsNegativeAtNight() {
        let calendar = parisCalendar
        let midnight = DateComponents(calendar: calendar, year: 2026, month: 8, day: 5, hour: 1).date!
        let sun = SunCalc.compute(at: midnight, latitude: 42.15, longitude: 9.08, calendar: calendar)
        XCTAssertLessThan(sun.elevation, 0)
    }
}
