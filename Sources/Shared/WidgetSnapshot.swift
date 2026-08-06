import Foundation

/// Instantané écrit par l'app dans le conteneur App Group et relu par
/// l'extension widget (sandboxée, donc sans accès direct au SolarFlow).
struct WidgetSnapshot: Codable, Equatable {
    /// Un jour de production pour l'histogramme du widget large.
    struct DayWh: Codable, Equatable {
        var day: String     // "2026-08-06"
        var wh: Double
    }

    var capturedAt: Date
    var solarInputPower: Double     // W
    var electricLevel: Double?      // %
    var outputHomePower: Double     // W
    var batteryFlow: Double         // W, >0 charge / <0 décharge
    var energyTodayWh: Double
    var solarHistory: [Double]      // derniers points pour la mini-courbe
    /// 14 derniers jours, du plus ancien au plus récent (aujourd'hui inclus).
    /// Optionnel : les snapshots écrits par les versions < 1.7 ne l'ont pas.
    var dailyEnergy: [DayWh]?

    static let sample = WidgetSnapshot(
        capturedAt: .now,
        solarInputPower: 842,
        electricLevel: 64,
        outputHomePower: 410,
        batteryFlow: 432,
        energyTodayWh: 3417,
        solarHistory: [220, 380, 520, 610, 590, 700, 820, 842],
        dailyEnergy: [1820, 2540, 900, 3100, 2870, 1500, 2200, 2954, 3417].enumerated().map {
            DayWh(day: "J-\(8 - $0.offset)", wh: Double($0.element))
        }
    )
}

/// Passe-plat app → widget via un fichier JSON atomique dans l'App Group
/// (même pattern que MacInside : plus sûr qu'un UserDefaults partagé pour une
/// lecture concurrente depuis un autre process).
enum WidgetSnapshotStore {
    /// Doit rester identique dans les entitlements de l'app ET de l'extension.
    static let appGroupIdentifier = "KFLACS69T9.fr.lauriat.ZendureMonitor"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("widget-snapshot.json")
    }

    @discardableResult
    static func write(_ snapshot: WidgetSnapshot) -> Bool {
        guard let fileURL else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return false }
        return (try? data.write(to: fileURL, options: .atomic)) != nil
    }

    enum ReadResult: Equatable {
        case available(WidgetSnapshot)
        /// Conteneur accessible mais l'app n'a encore rien publié.
        case notYetPublished
        /// Entitlement App Group absent (build local non signé avec --entitlements).
        case containerUnavailable
    }

    static func read() -> ReadResult {
        guard let fileURL else { return .containerUnavailable }
        guard let data = try? Data(contentsOf: fileURL) else { return .notYetPublished }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else {
            return .notYetPublished
        }
        return .available(snapshot)
    }
}
