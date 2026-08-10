import Foundation

/// Un jour d'historique d'énergie renvoyé par l'endpoint tdengine de l'API
/// privée de l'app Zendure. Les champs sont gardés bruts (clé → valeur) car
/// leur liste varie selon le productType (Hub 2000 : 4 champs, Hyper : 5…).
struct EnergyDay: Codable, Equatable, Identifiable {
    /// "yyyy-MM-dd"
    var date: String
    var fields: [String: Double]

    var id: String { date }

    /// Date réelle pour l'axe X des graphiques.
    var dateValue: Date? { Self.formatter.date(from: date) }

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

/// Libellés français des métriques d'historique connues (relevées dans le
/// module FHEM RP-Develop/Zendure). Les clés inconnues restent affichables
/// telles quelles.
enum EnergyMetricCatalog {
    static let labels: [String: String] = [
        "solar": "Solaire",
        "home": "Maison",
        "batteryInput": "Charge batterie",
        "batteryOutput": "Décharge batterie",
        "gridInputTotal": "Réseau (charge secteur)",
        "acOutputTotal": "Sortie AC",
        "dcOutputTotal": "Sortie DC",
        "socketOutputTotal": "Prise",
        "gridDirectTotal": "Réseau direct",
        "outputToInverse": "Vers onduleur",
        "outputToBindDevice": "Vers appareil lié",
        "bindDeviceInput": "Depuis appareil lié",
    ]

    static func label(for key: String) -> String {
        labels[key] ?? key
    }
}

/// Cache disque des jours d'historique déjà récupérés — un fichier JSON par
/// appareil dans Application Support. Évite de re-télécharger 365 jours à
/// chaque lancement (les jours passés sont immuables, seul « aujourd'hui »
/// est refait).
enum HistoryCache {
    private static var directory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = base.appendingPathComponent("ZendureMonitor/history", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func file(for deviceId: String) -> URL? {
        // L'id est alphanumérique côté Zendure ; on filtre par prudence.
        let safe = deviceId.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        guard !safe.isEmpty else { return nil }
        return directory?.appendingPathComponent("\(safe).json")
    }

    static func load(deviceId: String) -> [EnergyDay] {
        guard let url = file(for: deviceId),
              let data = try? Data(contentsOf: url),
              let days = try? JSONDecoder().decode([EnergyDay].self, from: data)
        else { return [] }
        return days
    }

    static func save(_ days: [EnergyDay], deviceId: String) {
        guard let url = file(for: deviceId),
              let data = try? JSONEncoder().encode(days) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
