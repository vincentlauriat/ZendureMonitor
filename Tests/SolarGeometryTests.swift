import XCTest

final class SolarGeometryTests: XCTestCase {

    // MARK: - Angle d'incidence

    /// Cas limite qui recolle au modèle historique : à plat, cos(incidence)
    /// vaut exactement sin(élévation), quel que soit l'azimut du soleil.
    func testFlatPanelReducesToSineOfElevation() {
        for elevation in [5.0, 22.0, 47.0, 78.0] {
            for azimuth in [0.0, 95.0, 180.0, 271.0] {
                let cosine = SolarGeometry.cosIncidence(sunElevation: elevation, sunAzimuth: azimuth,
                                                        tilt: 0, azimuth: 180)
                XCTAssertEqual(cosine, sin(elevation * .pi / 180), accuracy: 1e-12)
            }
        }
    }

    /// Panneau pointé pile sur le soleil : incidence nulle.
    func testPanelAimedAtSunHasZeroIncidence() {
        let elevation = 35.0
        let azimuth = 155.0
        let angle = SolarGeometry.incidenceAngle(sunElevation: elevation, sunAzimuth: azimuth,
                                                 tilt: 90 - elevation, azimuth: azimuth)
        XCTAssertEqual(angle, 0, accuracy: 1e-6)
    }

    /// Un panneau plein est à 15 h reçoit encore le diffus : jamais 0 W en
    /// plein jour, sinon la carte des orientations serait fausse.
    func testBackFacingArrayKeepsDiffuseFloor() {
        let east = PanelArray(peakWatts: 1000, azimuth: 90, tilt: 45)
        let watts = SolarGeometry.clearSkyWatts(for: east, sunElevation: 30, sunAzimuth: 265)
        XCTAssertGreaterThan(watts, 20)
        XCTAssertLessThan(watts, 200)
    }

    /// Le modèle reste dans le voisinage de l'ancienne estimation naïve
    /// (crête × sin(élévation) × 0,9) tout en restant systématiquement sous
    /// elle : l'atmosphère ne peut qu'atténuer.
    func testFlatArrayStaysUnderLegacyClearSkyFormula() {
        let flat = PanelArray(peakWatts: 800, azimuth: 180, tilt: 0)
        for elevation in [25.0, 41.0, 68.0] {
            let legacy = 800 * sin(elevation * .pi / 180) * 0.9
            let watts = SolarGeometry.clearSkyWatts(for: flat, sunElevation: elevation, sunAzimuth: 210)
            XCTAssertLessThan(watts, legacy)
            // L'écart vient de la seule traversée d'atmosphère : 20 à 25 % de
            // moins selon la hauteur du soleil, jamais un ordre de grandeur.
            XCTAssertGreaterThan(watts, legacy * 0.7)
        }
    }

    /// Transmittance : 1 au zénith, décroissante, effondrée à l'horizon — c'est
    /// ce qui empêche une façade ouest d'afficher son maximum au coucher.
    func testAtmosphericTransmittanceCollapsesNearHorizon() {
        XCTAssertEqual(SolarGeometry.atmosphericTransmittance(sunElevation: 90), 1, accuracy: 1e-3)
        let profile = [60.0, 40, 20, 10, 3, 1].map { SolarGeometry.atmosphericTransmittance(sunElevation: $0) }
        XCTAssertEqual(profile, profile.sorted(by: >))
        XCTAssertLessThan(profile.last!, 0.15)

        let westFacade = PanelArray(peakWatts: 500, azimuth: 265, tilt: 65)
        // Soleil couchant pile en face : géométriquement idéal, physiquement faible.
        let watts = SolarGeometry.clearSkyWatts(for: westFacade, sunElevation: 1.6, sunAzimuth: 290)
        XCTAssertLessThan(watts, 60)
    }

    func testNothingBelowHorizon() {
        let array = PanelArray(peakWatts: 1000, azimuth: 180, tilt: 30)
        XCTAssertEqual(SolarGeometry.clearSkyWatts(for: array, sunElevation: -3, sunAzimuth: 285), 0)
        XCTAssertNil(SolarGeometry.airMass(sunElevation: -0.5))
        XCTAssertNil(SolarGeometry.shadowRatio(sunElevation: 0))
    }

    /// Une orientation sud produit plus, sur la journée, qu'une orientation
    /// nord de même puissance — et l'est culmine avant l'ouest.
    func testOrientationsRankAsExpectedOverTheDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let june = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 12).date!
        let track = SunCalc.track(on: june, latitude: 42.15, longitude: 9.08, calendar: calendar)

        let south = PanelArray(peakWatts: 1000, azimuth: 180, tilt: 30)
        let north = PanelArray(peakWatts: 1000, azimuth: 0, tilt: 30)
        XCTAssertGreaterThan(SolarGeometry.clearSkyEnergyWh(for: [south], track: track),
                             SolarGeometry.clearSkyEnergyWh(for: [north], track: track))

        let east = PanelArray(peakWatts: 1000, azimuth: 90, tilt: 40)
        let west = PanelArray(peakWatts: 1000, azimuth: 270, tilt: 40)
        let bestEast = SolarGeometry.bestMoment(for: east, track: track)
        let bestWest = SolarGeometry.bestMoment(for: west, track: track)
        XCTAssertNotNil(bestEast)
        XCTAssertNotNil(bestWest)
        XCTAssertLessThan(bestEast!.date, bestWest!.date)
    }

    /// L'énergie de l'installation entière est la somme de ses champs.
    func testEnergyIsAdditiveAcrossArrays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let day = DateComponents(calendar: calendar, year: 2026, month: 4, day: 10, hour: 12).date!
        let track = SunCalc.track(on: day, latitude: 42.15, longitude: 9.08, calendar: calendar)
        let east = PanelArray(peakWatts: 600, azimuth: 100, tilt: 25)
        let west = PanelArray(peakWatts: 600, azimuth: 260, tilt: 25)

        XCTAssertEqual(SolarGeometry.clearSkyEnergyWh(for: [east, west], track: track),
                       SolarGeometry.clearSkyEnergyWh(for: [east], track: track)
                           + SolarGeometry.clearSkyEnergyWh(for: [west], track: track),
                       accuracy: 1e-6)
    }

    // MARK: - Contour d'iso-incidence

    /// Chaque point du contour est bien à l'angle demandé de la normale —
    /// c'est ce qui garantit que les anneaux tracés dans le ciel sont justes.
    func testIncidenceLocusStaysAtRequestedAngle() {
        for (tilt, azimuth) in [(0.0, 180.0), (30.0, 135.0), (65.0, 250.0)] {
            for angle in [25.0, 50.0] {
                for direction in SolarGeometry.incidenceLocus(tilt: tilt, azimuth: azimuth, angle: angle) {
                    let measured = SolarGeometry.incidenceAngle(sunElevation: direction.elevation,
                                                               sunAzimuth: direction.azimuth,
                                                               tilt: tilt, azimuth: azimuth)
                    XCTAssertEqual(measured, angle, accuracy: 1e-6)
                }
            }
        }
    }

    /// Panneau à plat : le contour est un cercle d'élévation constante.
    func testFlatPanelLocusIsConstantElevation() {
        for direction in SolarGeometry.incidenceLocus(tilt: 0, azimuth: 180, angle: 25) {
            XCTAssertEqual(direction.elevation, 65, accuracy: 1e-6)
        }
    }

    // MARK: - Persistance

    func testStoreMigratesLegacyPeakWattsToSingleSouthArray() {
        let defaults = UserDefaults(suiteName: "SolarGeometryTests.legacy")!
        defaults.removePersistentDomain(forName: "SolarGeometryTests.legacy")
        defaults.set(1200.0, forKey: PanelArrayStore.legacyPeakKey)

        let arrays = PanelArrayStore.load(from: defaults)
        XCTAssertEqual(arrays.count, 1)
        XCTAssertEqual(arrays.first?.peakWatts, 1200)
        XCTAssertEqual(arrays.first?.azimuth, 180)
        XCTAssertEqual(arrays.first?.tilt, 30)
    }

    func testStoreRoundTripsArrays() {
        let defaults = UserDefaults(suiteName: "SolarGeometryTests.roundtrip")!
        defaults.removePersistentDomain(forName: "SolarGeometryTests.roundtrip")
        let arrays = [PanelArray(name: "Toit sud", peakWatts: 900, azimuth: 175, tilt: 28),
                      PanelArray(name: "", peakWatts: 400, azimuth: 265, tilt: 15)]

        PanelArrayStore.save(arrays, to: defaults)
        XCTAssertEqual(PanelArrayStore.load(from: defaults), arrays)
    }

    func testStorePrefersArraysOverLegacyKey() {
        let defaults = UserDefaults(suiteName: "SolarGeometryTests.priority")!
        defaults.removePersistentDomain(forName: "SolarGeometryTests.priority")
        defaults.set(3000.0, forKey: PanelArrayStore.legacyPeakKey)
        PanelArrayStore.save([PanelArray(peakWatts: 500, azimuth: 90, tilt: 10)], to: defaults)

        XCTAssertEqual(PanelArrayStore.load(from: defaults).map(\.peakWatts), [500])
    }
}
