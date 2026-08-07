import XCTest

final class OutageWatchdogTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeWatchdog() -> OutageWatchdog {
        OutageWatchdog(unreachableAfter: 600, anomalyAfter: 1800,
                       minElevation: 20, idleWatts: 10, startedAt: t0)
    }

    // MARK: - Injoignable

    func testNoUnreachableEventBeforeThreshold() {
        var dog = makeWatchdog()
        XCTAssertNil(dog.pollFailed(at: t0 + 599))
        XCTAssertFalse(dog.isOffline(at: t0 + 599))
    }

    func testUnreachableFiresOnceAfterThreshold() {
        var dog = makeWatchdog()
        XCTAssertEqual(dog.pollFailed(at: t0 + 600), .unreachable(since: t0))
        XCTAssertNil(dog.pollFailed(at: t0 + 700), "une seule notification par épisode")
        XCTAssertTrue(dog.isOffline(at: t0 + 700))
    }

    func testRecoveryRearmsUnreachable() {
        var dog = makeWatchdog()
        _ = dog.pollFailed(at: t0 + 600)
        _ = dog.deviceResponded(solarW: 500, homeW: 300, elevation: 40, at: t0 + 900)
        XCTAssertFalse(dog.isOffline(at: t0 + 900))
        XCTAssertNil(dog.pollFailed(at: t0 + 1000), "silence trop court après reprise")
        XCTAssertEqual(dog.pollFailed(at: t0 + 1500), .unreachable(since: t0 + 900),
                       "nouvel épisode → nouvelle notification")
    }

    func testSuccessfulPollClearsOfflineState() {
        var dog = makeWatchdog()
        _ = dog.pollFailed(at: t0 + 600)
        _ = dog.deviceResponded(solarW: 0, homeW: 0, elevation: -10, at: t0 + 650)
        XCTAssertFalse(dog.isOffline(at: t0 + 650))
    }

    // MARK: - Production anormale

    func testAnomalyFiresAfterSustainedIdleDaylight() {
        var dog = makeWatchdog()
        XCTAssertNil(dog.deviceResponded(solarW: 0, homeW: 0, elevation: 45, at: t0))
        XCTAssertNil(dog.deviceResponded(solarW: 3, homeW: 0, elevation: 45, at: t0 + 900))
        XCTAssertEqual(dog.deviceResponded(solarW: 0, homeW: 5, elevation: 45, at: t0 + 1800),
                       .productionAnomaly(since: t0))
        XCTAssertNil(dog.deviceResponded(solarW: 0, homeW: 0, elevation: 45, at: t0 + 2400),
                     "une seule notification tant que l'anomalie persiste")
    }

    func testProductionResumingResetsAnomaly() {
        var dog = makeWatchdog()
        _ = dog.deviceResponded(solarW: 0, homeW: 0, elevation: 45, at: t0)
        _ = dog.deviceResponded(solarW: 400, homeW: 250, elevation: 45, at: t0 + 900)
        XCTAssertNil(dog.deviceResponded(solarW: 0, homeW: 0, elevation: 45, at: t0 + 1000),
                     "le compteur repart de zéro après une reprise")
        XCTAssertEqual(dog.deviceResponded(solarW: 0, homeW: 0, elevation: 45, at: t0 + 2800),
                       .productionAnomaly(since: t0 + 1000))
    }

    func testNoAnomalyAtLowSunOrWithoutPosition() {
        var dog = makeWatchdog()
        XCTAssertNil(dog.deviceResponded(solarW: 0, homeW: 0, elevation: 10, at: t0))
        XCTAssertNil(dog.deviceResponded(solarW: 0, homeW: 0, elevation: 10, at: t0 + 3600),
                     "soleil bas : aucune production attendue")
        XCTAssertNil(dog.deviceResponded(solarW: 0, homeW: 0, elevation: -90, at: t0 + 7200),
                     "élévation sentinelle (position non configurée) : détection coupée")
    }

    func testHomeInjectionAloneIsNotAnAnomaly() {
        var dog = makeWatchdog()
        _ = dog.deviceResponded(solarW: 0, homeW: 320, elevation: 45, at: t0)
        XCTAssertNil(dog.deviceResponded(solarW: 0, homeW: 320, elevation: 45, at: t0 + 3600),
                     "batterie qui injecte vers la maison = appareil sain")
    }
}
