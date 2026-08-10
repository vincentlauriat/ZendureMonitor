import Foundation

/// Parseur de la réponse Overpass (`out geom`) — pur, testé sans réseau.
enum OverpassParser {
    /// Hauteur par défaut d'un bâtiment sans tag exploitable (pavillon R+1).
    static let defaultHeight = 6.0
    /// Mètres par étage quand seul `building:levels` est renseigné.
    static let metersPerLevel = 3.0

    static func parse(_ data: Data) throws -> SunRoadNeighborhood {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let elements = root["elements"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }
        var buildings: [SunRoadBuilding] = []
        var roads: [SunRoadRoad] = []
        for element in elements {
            guard element["type"] as? String == "way",
                  let geometry = element["geometry"] as? [[String: Any]] else { continue }
            let points = geometry.compactMap { entry -> SunRoadBuilding.GeoPoint? in
                guard let lat = entry["lat"] as? Double, let lon = entry["lon"] as? Double else { return nil }
                return .init(lat: lat, lon: lon)
            }
            let tags = element["tags"] as? [String: String] ?? [:]
            if let highway = tags["highway"] {
                // Une route est une polyligne : 2 points suffisent.
                guard points.count >= 2 else { continue }
                let (width, footpath) = roadProfile(highway: highway)
                roads.append(SunRoadRoad(points: points, width: width, footpath: footpath))
            } else if tags["building"] != nil {
                guard points.count >= 3 else { continue }
                buildings.append(SunRoadBuilding(points: points, height: height(from: tags)))
            }
        }
        return SunRoadNeighborhood(buildings: buildings, roads: roads)
    }

    /// Largeur de chaussée plausible (m) par classe `highway`, et caractère
    /// piéton (rendu plus fin et plus clair).
    static func roadProfile(highway: String) -> (width: Double, footpath: Bool) {
        switch highway {
        case "motorway", "trunk": return (9, false)
        case "primary": return (8, false)
        case "secondary": return (7, false)
        case "tertiary": return (6, false)
        case "residential", "unclassified", "living_street": return (5, false)
        case "service": return (3.5, false)
        case "track": return (3, false)
        case "footway", "path", "cycleway", "pedestrian", "steps", "bridleway":
            return (1.8, true)
        default: return (4, false)
        }
    }

    /// `height` (mètres, tolère « 7.5 m ») prioritaire, sinon
    /// `building:levels` × 3 m, sinon 6 m.
    static func height(from tags: [String: String]) -> Double {
        if let raw = tags["height"] {
            let cleaned = raw.replacingOccurrences(of: ",", with: ".")
                .filter { $0.isNumber || $0 == "." || $0 == "-" }
            if let value = Double(cleaned), value > 0 { return min(value, 60) }
        }
        if let raw = tags["building:levels"], let levels = Double(raw), levels > 0 {
            return min(levels * Self.metersPerLevel, 60)
        }
        return Self.defaultHeight
    }
}

/// Cache disque du quartier — un JSON par localisation arrondie (~11 m) :
/// les bâtiments ne bougent pas, un seul fetch Overpass suffit.
enum SunRoadCache {
    private static var directory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = base.appendingPathComponent("ZendureMonitor/sunroad", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Suffixe `_v2` : le format v1 (bâtiments seuls) est simplement refetché.
    private static func file(latitude: Double, longitude: Double) -> URL? {
        directory?.appendingPathComponent(String(format: "%.4f_%.4f_v2.json", latitude, longitude))
    }

    static func load(latitude: Double, longitude: Double) -> SunRoadNeighborhood? {
        guard let url = file(latitude: latitude, longitude: longitude),
              let data = try? Data(contentsOf: url),
              let neighborhood = try? JSONDecoder().decode(SunRoadNeighborhood.self, from: data)
        else { return nil }
        return neighborhood
    }

    static func save(_ neighborhood: SunRoadNeighborhood, latitude: Double, longitude: Double) {
        guard let url = file(latitude: latitude, longitude: longitude),
              let data = try? JSONEncoder().encode(neighborhood) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// Récupération des emprises de bâtiments autour de la maison via l'API
/// publique Overpass (OpenStreetMap). Gratuite, sans clé — on la ménage :
/// cache agressif, un seul rayon, plafond de résultats.
enum OverpassService {
    static let radiusMeters = 120
    /// Les routes un peu plus loin que les bâtiments : elles structurent la vue.
    static let roadRadiusMeters = 170
    static let maxBuildings = 250
    static let maxRoads = 200
    private static let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!

    /// Quartier depuis le cache, sinon depuis Overpass (`force` re-télécharge).
    static func neighborhood(latitude: Double, longitude: Double,
                             force: Bool = false) async throws -> SunRoadNeighborhood {
        if !force, let cached = SunRoadCache.load(latitude: latitude, longitude: longitude) {
            return cached
        }
        let query = """
        [out:json][timeout:25];
        (
          way["building"](around:\(radiusMeters),\(latitude),\(longitude));
          way["highway"](around:\(roadRadiusMeters),\(latitude),\(longitude));
        );
        out geom \((maxBuildings + maxRoads) * 2);
        """
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("data=\(query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query)".utf8)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        // Les plus proches d'abord, plafonnés — la scène reste fluide.
        let parsed = try OverpassParser.parse(data)
        let buildings = parsed.buildings
            .sorted {
                GeoProjection.distance(from: $0, originLat: latitude, originLon: longitude)
                    < GeoProjection.distance(from: $1, originLat: latitude, originLon: longitude)
            }
            .prefix(maxBuildings)
        let result = SunRoadNeighborhood(buildings: Array(buildings),
                                         roads: Array(parsed.roads.prefix(maxRoads)))
        SunRoadCache.save(result, latitude: latitude, longitude: longitude)
        return result
    }
}
