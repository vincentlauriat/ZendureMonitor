import Foundation

/// Mesure du compteur Zendure Smart CT (SmartMeter3CT), lue sur son API
/// locale zenSDK : `GET http://<hôte>/properties/report` renvoie un payload
/// à plat — puissance apparente par phase et total au point de comptage :
/// `{"a_aprt_power": 0, "b_aprt_power": 0, "c_aprt_power": 2089,
///   "total_power": 2089, "deviceId": "…", …}`.
///
/// `totalPower` est ce que la maison soutire du réseau public (le compteur
/// voit passer la charge secteur du SolarFlow aussi — l'appelant la déduit
/// s'il veut le soutirage « maison seule »).
struct CTReport: Equatable {
    var totalPower: Double
    /// Puissances par phase (A, B, C), en W — absentes si le firmware ne les
    /// publie pas.
    var phases: [Double]
    var deviceId: String?
    var updatedAt: Date = .now
}

enum SmartCTParser {
    static func parse(_ data: Data, at date: Date = .now) throws -> CTReport {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ZendureError.badPayload
        }
        let props = (root["properties"] as? [String: Any]) ?? root
        func num(_ key: String) -> Double? {
            switch props[key] {
            case let d as Double: return d
            case let i as Int: return Double(i)
            case let n as NSNumber: return n.doubleValue
            case let s as String: return Double(s)
            default: return nil
            }
        }
        let phases = ["a_aprt_power", "b_aprt_power", "c_aprt_power"].compactMap(num)
        guard let total = num("total_power") ?? (phases.isEmpty ? nil : phases.reduce(0, +)) else {
            throw ZendureError.badPayload
        }
        return CTReport(totalPower: total,
                        phases: phases,
                        deviceId: props["deviceId"] as? String,
                        updatedAt: date)
    }
}
