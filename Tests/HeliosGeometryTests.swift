import XCTest

final class HeliosGeometryTests: XCTestCase {
    func testDomePointCardinals() {
        // Nord à l'horizon → -Z ; est → +X ; zénith → +Y.
        let north = HeliosGeometry.domePoint(azimuth: 0, elevation: 0, radius: 10)
        XCTAssertEqual(north.x, 0, accuracy: 1e-9)
        XCTAssertEqual(north.z, -10, accuracy: 1e-9)

        let east = HeliosGeometry.domePoint(azimuth: 90, elevation: 0, radius: 10)
        XCTAssertEqual(east.x, 10, accuracy: 1e-9)
        XCTAssertEqual(east.z, 0, accuracy: 1e-9)

        let zenith = HeliosGeometry.domePoint(azimuth: 123, elevation: 90, radius: 10)
        XCTAssertEqual(zenith.y, 10, accuracy: 1e-9)
        XCTAssertEqual(zenith.x, 0, accuracy: 1e-6)
    }

    func testDomePointSouthElevated() {
        // Sud à 45° : mi-hauteur, +Z, jamais de X.
        let p = HeliosGeometry.domePoint(azimuth: 180, elevation: 45, radius: 10)
        XCTAssertEqual(p.x, 0, accuracy: 1e-9)
        XCTAssertEqual(p.y, 10 * sin(Double.pi / 4), accuracy: 1e-9)
        XCTAssertEqual(p.z, 10 * cos(Double.pi / 4), accuracy: 1e-9)
    }

    func testPanelAreaBounds() {
        XCTAssertEqual(HeliosGeometry.panelArea(peakWatts: 2000), 10, accuracy: 1e-9)  // ~200 Wc/m²
        XCTAssertEqual(HeliosGeometry.panelArea(peakWatts: 0), 1)          // plancher lisible
        XCTAssertEqual(HeliosGeometry.panelArea(peakWatts: 100_000), 40)   // plafond scène
    }

    func testDaylightFactorRamp() {
        XCTAssertEqual(HeliosGeometry.daylightFactor(elevation: -10), 0)   // nuit
        XCTAssertEqual(HeliosGeometry.daylightFactor(elevation: 15), 1)    // plein jour
        XCTAssertEqual(HeliosGeometry.daylightFactor(elevation: -6), 0, accuracy: 1e-9)
        let mid = HeliosGeometry.daylightFactor(elevation: 4.5)            // milieu de rampe
        XCTAssertEqual(mid, 0.5, accuracy: 1e-9)
    }
}
