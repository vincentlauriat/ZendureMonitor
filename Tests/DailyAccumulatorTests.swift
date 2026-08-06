import XCTest

final class DailyAccumulatorTests: XCTestCase {

    private let day = "2026-08-06"
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testFirstSampleCreditsNothing() {
        var acc = DailyAccumulator(day: day)
        acc.ingest(solar: 600, charge: 0, gridIn: 0, at: t0, dayKey: day,
                   minuteOfDay: 600, maxDt: 15)
        XCTAssertEqual(acc.solarWh, 0)
        XCTAssertEqual(acc.peakW, 600)
    }

    func testIntegrationOverSteadySamples() {
        var acc = DailyAccumulator(day: day)
        // 600 W pendant 60 s (12 pas de 5 s) = 10 Wh.
        for i in 0...12 {
            acc.ingest(solar: 600, charge: 0, gridIn: 0,
                       at: t0.addingTimeInterval(Double(i) * 5), dayKey: day,
                       minuteOfDay: 600, maxDt: 15)
        }
        XCTAssertEqual(acc.solarWh, 10, accuracy: 0.001)
    }

    func testSleepGapIsCapped() {
        var acc = DailyAccumulator(day: day)
        acc.ingest(solar: 600, charge: 0, gridIn: 0, at: t0, dayKey: day,
                   minuteOfDay: 600, maxDt: 15)
        // Réveil 2 h plus tard : le pas est borné à maxDt (15 s), pas 2 h.
        acc.ingest(solar: 600, charge: 0, gridIn: 0, at: t0.addingTimeInterval(7200),
                   dayKey: day, minuteOfDay: 720, maxDt: 15)
        XCTAssertEqual(acc.solarWh, 600 * 15 / 3600, accuracy: 0.001)
    }

    func testResetSampleClockAfterOutage() {
        var acc = DailyAccumulator(day: day)
        acc.ingest(solar: 600, charge: 0, gridIn: 0, at: t0, dayKey: day,
                   minuteOfDay: 600, maxDt: 15)
        acc.resetSampleClock()
        // Après un trou de mesure : l'échantillon suivant ne crédite rien.
        acc.ingest(solar: 600, charge: 0, gridIn: 0, at: t0.addingTimeInterval(30),
                   dayKey: day, minuteOfDay: 600, maxDt: 15)
        XCTAssertEqual(acc.solarWh, 0)
    }

    func testDayRolloverResetsEverything() {
        var acc = DailyAccumulator(day: day, solarWh: 4200, storedWh: 1000,
                                   gridWh: 50, curve: [100, 200], peakW: 900)
        let rolled = acc.ingest(solar: 10, charge: 0, gridIn: 0, at: t0,
                                dayKey: "2026-08-07", minuteOfDay: 0, maxDt: 15)
        XCTAssertTrue(rolled)
        XCTAssertEqual(acc.day, "2026-08-07")
        XCTAssertEqual(acc.solarWh, 0)
        XCTAssertEqual(acc.storedWh, 0)
        XCTAssertEqual(acc.gridWh, 0)
        XCTAssertEqual(acc.peakW, 10)
        XCTAssertEqual(acc.curve, [10])
    }

    func testCurveBucketsKeepMax() {
        var acc = DailyAccumulator(day: day)
        acc.ingest(solar: 300, charge: 0, gridIn: 0, at: t0, dayKey: day,
                   minuteOfDay: 7, maxDt: 15)   // bucket 1
        acc.ingest(solar: 500, charge: 0, gridIn: 0, at: t0.addingTimeInterval(5),
                   dayKey: day, minuteOfDay: 8, maxDt: 15)   // bucket 1 aussi
        acc.ingest(solar: 200, charge: 0, gridIn: 0, at: t0.addingTimeInterval(10),
                   dayKey: day, minuteOfDay: 9, maxDt: 15)
        XCTAssertEqual(acc.curve, [0, 500])
    }

    func testStoredAndGridAccumulate() {
        var acc = DailyAccumulator(day: day)
        acc.ingest(solar: 800, charge: 500, gridIn: 200, at: t0, dayKey: day,
                   minuteOfDay: 600, maxDt: 15)
        acc.ingest(solar: 800, charge: 500, gridIn: 200,
                   at: t0.addingTimeInterval(3600), dayKey: day,
                   minuteOfDay: 660, maxDt: 3600)
        XCTAssertEqual(acc.solarWh, 800, accuracy: 0.001)
        XCTAssertEqual(acc.storedWh, 300, accuracy: 0.001)  // 500 − 200 de réseau
        XCTAssertEqual(acc.gridWh, 200, accuracy: 0.001)
    }

    func testMergeSolarWhKeepsBest() {
        var acc = DailyAccumulator(day: day, solarWh: 1000)
        acc.mergeSolarWh(800)
        XCTAssertEqual(acc.solarWh, 1000)
        acc.mergeSolarWh(1500)
        XCTAssertEqual(acc.solarWh, 1500)
    }
}
