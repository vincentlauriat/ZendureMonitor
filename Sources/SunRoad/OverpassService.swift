import Foundation

/// Parseur de la réponse Overpass (`out geom`) — pur, testé sans réseau.
enum OverpassParser {
    /// Hauteur par défaut d'un bâtiment sans tag exploitable (pavillon R+1).
    static let defaultHeight = 6.0
    /// Mètres par étage quand seul `building:levels` est renseigné.
    static let metersPerLevel = 3.0

    static func parse(_ data: Data) throws -> [SunRoadBuilding] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let elements = root["elements"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }
        return elements.compactMap { element in
            guard element["type"] as? String == "way",
                  let geometry = element["geometry"] as? [[String: Any]] else { return nil }
            let points = geometry.compactMap { entry -> SunRoadBuilding.GeoPoint? in
                guard let lat = entry["lat"] as? Double, let lon = entry["lon"] as? Double else { return nil }
                return .init(lat: lat, lon: lon)
            }
            guard points.count >= 3 else { return nil }
            let tags = element["tags"] as? [String: String] ?? [:]
            return SunRoadBuilding(points: points, height: height(from: tags))
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

    private static func file(latitude: Double, longitude: Double) -> URL? {
        directory?.appendingPathComponent(String(format: "%.4f_%.4f.json", latitude, longitude))
    }

    static func load(latitude: Double, longitude: Double) -> [SunRoadBuilding]? {
        guard let url = file(latitude: latitude, longitude: longitude),
              let data = try? Data(contentsOf: url),
              let buildings = try? JSONDecoder().decode([SunRoadBuilding].self, from: data)
        else { return nil }
        return buildings
    }

    static func save(_ buildings: [SunRoadBuilding], latitude: Double, longitude: Double) {
        guard let url = file(latitude: latitude, longitude: longitude),
              let data = try? JSONEncoder().encode(buildings) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// Récupération des emprises de bâtiments autour de la maison via l'API
/// publique Overpass (OpenStreetMap). Gratuite, sans clé — on la ménage :
/// cache agressif, un seul rayon, plafond de résultats.
enum OverpassService {
    static let radiusMeters = 120
    static let maxBuildings = 250
    private static let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!

    /// Quartier depuis le cache, sinon depuis Overpass (`force` re-télécharge).
    static func neighborhood(latitude: Double, longitude: Double,
                             force: Bool = false) async throws -> [SunRoadBuilding] {
        if !force, let cached = SunRoadCache.load(latitude: latitude, longitude: longitude) {
            return cached
        }
        let query = """
        [out:json][timeout:25];
        way["building"](around:\(radiusMeters),\(latitude),\(longitude));
        out geom \(maxBuildings * 2);
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
        let buildings = try OverpassParser.parse(data)
            .sorted {
                GeoProjection.distance(from: $0, originLat: latitude, originLon: longitude)
                    < GeoProjection.distance(from: $1, originLat: latitude, originLon: longitude)
            }
            .prefix(maxBuildings)
        let result = Array(buildings)
        SunRoadCache.save(result, latitude: latitude, longitude: longitude)
        return result
    }
}
