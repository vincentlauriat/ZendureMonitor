import Foundation

/// One physical battery pack, from the `packData` array of the report.
struct PackInfo: Identifiable, Equatable {
    var id: String { serialNumber }
    var serialNumber: String
    var socLevel: Double?      // %
    var temperature: Double?   // °C (report gives 0.1 K)
    var power: Double?         // W

    /// `maxTemp` arrives in tenths of kelvin (e.g. 3081 → 35 °C).
    static func celsius(fromTenthsKelvin raw: Double) -> Double {
        raw / 10.0 - 273.15
    }
}

/// Snapshot of the SolarFlow device, parsed from `GET /properties/report` (zenSDK local API).
struct DeviceState {
    var solarInputPower: Double = 0      // W — total PV input
    var solarChannels: [Double] = []     // W — per-MPPT (solarPower1…6)
    var electricLevel: Double?           // % — average SOC
    var outputHomePower: Double = 0      // W — output to home
    var gridInputPower: Double = 0       // W — grid input (AC charging)
    var packInputPower: Double = 0       // W — battery discharge
    var outputPackPower: Double = 0      // W — battery charge
    var offGridPower: Double = 0         // W — prise de secours hors réseau (gridOffPower)
    var serialNumber: String?
    var packs: [PackInfo] = []
    var acMode: Int?                     // 1 = charge secteur, 2 = injection
    var inputLimit: Double?              // W — plafond de charge AC
    var outputLimit: Double?             // W — plafond de sortie
    var deviceTemperature: Double?       // °C (hyperTmp, 0.1 K)
    var remainOutMinutes: Double?        // min — autonomie estimée en décharge
    var rssi: Double?                    // dBm — signal WiFi du device
    var batteryVoltage: Double?          // V (BatVolt, 0.01 V)
    var socMax: Double?                  // % — plafond de charge (socSet, 0.1 %)
    var socMin: Double?                  // % — plancher de décharge (minSoc, 0.1 %)
    var updatedAt: Date = .now

    /// Positive = charging, negative = discharging.
    var batteryFlow: Double { outputPackPower - packInputPower }
}

enum ZendureParser {
    /// Parses a `/properties/report` payload. The report nests values under
    /// `properties` on current firmwares, but older ones return them flat —
    /// both shapes are accepted, and numbers may arrive as Int, Double or String.
    static func parse(_ data: Data) throws -> DeviceState {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ZendureError.badPayload
        }
        let props = (root["properties"] as? [String: Any]) ?? root

        var state = DeviceState()
        state.solarInputPower = number(props["solarInputPower"]) ?? 0
        state.electricLevel = number(props["electricLevel"]) ?? number(props["socLevel"])
        state.outputHomePower = number(props["outputHomePower"]) ?? 0
        state.gridInputPower = number(props["gridInputPower"]) ?? 0
        state.packInputPower = number(props["packInputPower"]) ?? 0
        state.outputPackPower = number(props["outputPackPower"]) ?? 0
        state.offGridPower = number(props["gridOffPower"]) ?? 0
        state.serialNumber = (root["sn"] as? String) ?? (props["sn"] as? String)
        state.solarChannels = (1...6).compactMap { number(props["solarPower\($0)"]) }
        state.acMode = number(props["acMode"]).map(Int.init)
        state.inputLimit = number(props["inputLimit"])
        state.outputLimit = number(props["outputLimit"])
        state.deviceTemperature = number(props["hyperTmp"]).map { $0 / 10.0 - 273.15 }
        // remainOutTime vaut 59940 quand l'estimation est indisponible (batterie à l'arrêt).
        state.remainOutMinutes = number(props["remainOutTime"]).flatMap { $0 >= 59940 ? nil : $0 }
        state.rssi = number(props["rssi"])
        state.batteryVoltage = number(props["BatVolt"]).map { $0 / 100.0 }
        state.socMax = number(props["socSet"]).map { $0 / 10.0 }
        state.socMin = number(props["minSoc"]).map { $0 / 10.0 }
        if let packData = root["packData"] as? [[String: Any]] {
            state.packs = packData.compactMap { pack in
                guard let sn = pack["sn"] as? String else { return nil }
                return PackInfo(
                    serialNumber: sn,
                    socLevel: number(pack["socLevel"]),
                    temperature: number(pack["maxTemp"]).map(PackInfo.celsius(fromTenthsKelvin:)),
                    power: number(pack["power"])
                )
            }
        }
        state.updatedAt = .now
        return state
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }
}

enum ZendureError: LocalizedError {
    case badPayload
    case badResponse(Int)
    case noHost
    case noCloudKey
    case cloudWaiting
    case cloudStale
    case cloudUnavailable(String)
    case cloudReadOnly

    var errorDescription: String? {
        switch self {
        case .badPayload: return String(localized: "Réponse du device illisible (JSON inattendu).")
        case .badResponse(let code): return String(localized: "Le device a répondu HTTP \(code).")
        case .noHost: return String(localized: "Aucune adresse configurée — ouvrez les Réglages.")
        case .noCloudKey: return String(localized: "Aucune Cloud Key enregistrée — ouvrez les Réglages.")
        case .cloudWaiting: return String(localized: "En attente des premières données du cloud Zendure…")
        case .cloudStale: return String(localized: "Plus de données du cloud Zendure depuis 3 minutes.")
        case .cloudUnavailable(let message): return message
        case .cloudReadOnly: return String(localized: "Le contrôle n'est pas disponible en mode Cloud (lecture seule).")
        }
    }
}
