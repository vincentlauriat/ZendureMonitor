import Foundation

/// Un bâtiment du quartier : emprise au sol (lat/lon OSM) et hauteur estimée.
struct SunRoadBuilding: Codable, Equatable {
    struct GeoPoint: Codable, Equatable {
        var lat: Double
        var lon: Double
    }

    var points: [GeoPoint]
    var height: Double
}

/// Une route du quartier : polyligne (lat/lon OSM), largeur déduite de la
/// classe `highway`, et distinction piéton (rendu plus clair et plus fin).
struct SunRoadRoad: Codable, Equatable {
    var points: [SunRoadBuilding.GeoPoint]
    var width: Double
    var footpath: Bool
}

/// Le quartier complet tel que mis en cache — bâtiments et routes.
struct SunRoadNeighborhood: Codable, Equatable {
    var buildings: [SunRoadBuilding]
    var roads: [SunRoadRoad]

    static let empty = SunRoadNeighborhood(buildings: [], roads: [])
}

/// Projection locale lat/lon → mètres autour d'un point d'origine.
/// Équirectangulaire : l'erreur est négligeable à l'échelle d'un quartier
/// (< 0,1 % à 200 m). Fonctions pures, testées.
enum GeoProjection {
    /// Mètres par degré de latitude (WGS-84, valeur moyenne).
    static let metersPerDegreeLatitude = 110_574.0
    /// Mètres par degré de longitude à l'équateur.
    static let metersPerDegreeLongitude = 111_320.0

    /// Position en mètres (est, nord) d'un point par rapport à l'origine.
    static func meters(lat: Double, lon: Double,
                       originLat: Double, originLon: Double) -> (east: Double, north: Double) {
        let east = (lon - originLon) * cos(originLat * .pi / 180) * Self.metersPerDegreeLongitude
        let north = (lat - originLat) * Self.metersPerDegreeLatitude
        return (east, north)
    }

    /// Centre de l'emprise (moyenne des sommets — suffisant pour trier par
    /// distance et repérer la maison).
    static func centroid(of building: SunRoadBuilding) -> SunRoadBuilding.GeoPoint {
        guard !building.points.isEmpty else { return .init(lat: 0, lon: 0) }
        let lat = building.points.map(\.lat).reduce(0, +) / Double(building.points.count)
        let lon = building.points.map(\.lon).reduce(0, +) / Double(building.points.count)
        return .init(lat: lat, lon: lon)
    }

    /// Distance en mètres entre l'origine et le centre d'un bâtiment.
    static func distance(from building: SunRoadBuilding,
                         originLat: Double, originLon: Double) -> Double {
        let c = centroid(of: building)
        let m = meters(lat: c.lat, lon: c.lon, originLat: originLat, originLon: originLon)
        return (m.east * m.east + m.north * m.north).squareRoot()
    }
}
