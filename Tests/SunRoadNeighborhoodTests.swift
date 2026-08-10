import XCTest

final class GeoProjectionTests: XCTestCase {
    func testMetersAtEquator() {
        let m = GeoProjection.meters(lat: 0.001, lon: 0.001, originLat: 0, originLon: 0)
        XCTAssertEqual(m.north, 110.574, accuracy: 0.001)
        XCTAssertEqual(m.east, 111.320, accuracy: 0.001)
    }

    func testMetersAt45North() {
        // À 45° nord, un degré de longitude vaut cos(45°) fois moins.
        let m = GeoProjection.meters(lat: 45, lon: 0.001, originLat: 45, originLon: 0)
        XCTAssertEqual(m.east, 111.320 * cos(Double.pi / 4), accuracy: 0.001)
        XCTAssertEqual(m.north, 0, accuracy: 1e-9)
    }

    func testCentroidAndDistance() {
        let building = SunRoadBuilding(
            points: [.init(lat: 0.0010, lon: 0), .init(lat: 0.0020, lon: 0),
                     .init(lat: 0.0020, lon: 0.0010), .init(lat: 0.0010, lon: 0.0010)],
            height: 6
        )
        let c = GeoProjection.centroid(of: building)
        XCTAssertEqual(c.lat, 0.0015, accuracy: 1e-9)
        XCTAssertEqual(c.lon, 0.0005, accuracy: 1e-9)
        let d = GeoProjection.distance(from: building, originLat: 0, originLon: 0)
        XCTAssertEqual(d, (165.861 * 165.861 + 55.66 * 55.66).squareRoot(), accuracy: 0.1)
    }
}

final class OverpassParserTests: XCTestCase {
    private let fixture = #"""
    {"elements":[
      {"type":"way","id":1,"tags":{"building":"house","height":"7.5 m"},
       "geometry":[{"lat":48.1,"lon":2.1},{"lat":48.1001,"lon":2.1},{"lat":48.1001,"lon":2.1001},{"lat":48.1,"lon":2.1001}]},
      {"type":"way","id":2,"tags":{"building":"yes","building:levels":"2"},
       "geometry":[{"lat":48.2,"lon":2.2},{"lat":48.2001,"lon":2.2},{"lat":48.2001,"lon":2.2001}]},
      {"type":"way","id":3,"tags":{"building":"yes"},
       "geometry":[{"lat":48.3,"lon":2.3},{"lat":48.3001,"lon":2.3}]},
      {"type":"node","id":4,"lat":48.4,"lon":2.4}
    ]}
    """#

    func testParseFixture() throws {
        let buildings = try OverpassParser.parse(Data(fixture.utf8))
        // Le way à 2 points (dégénéré) et le node sont écartés.
        XCTAssertEqual(buildings.count, 2)
        XCTAssertEqual(buildings[0].points.count, 4)
        XCTAssertEqual(buildings[0].height, 7.5)          // "7.5 m" nettoyé
        XCTAssertEqual(buildings[1].height, 6)            // 2 niveaux × 3 m
    }

    func testHeightFallbacks() {
        XCTAssertEqual(OverpassParser.height(from: [:]), 6)                        // défaut
        XCTAssertEqual(OverpassParser.height(from: ["height": "12,5"]), 12.5)      // virgule tolérée
        XCTAssertEqual(OverpassParser.height(from: ["height": "n/a"]), 6)          // illisible → défaut
        XCTAssertEqual(OverpassParser.height(from: ["building:levels": "4"]), 12)
        XCTAssertEqual(OverpassParser.height(from: ["height": "500"]), 60)         // plafonné
    }

    func testParseRejectsGarbage() {
        XCTAssertThrowsError(try OverpassParser.parse(Data("pas du json".utf8)))
    }
}
