import Foundation

/// État fusionné d'un appareil, alimenté par les messages MQTT
/// `properties/report` du cloud Zendure. Les rapports sont PARTIELS : on
/// fusionne champ par champ, on ne remplace jamais l'état entier —
/// contrairement au mode local où chaque `GET /properties/report` renvoie un
/// instantané complet (voir ZendureParser).
struct CloudDeviceState: Equatable {
    /// Un pack batterie (entrée du tableau `packData`), fusionné par `sn`.
    struct Pack: Equatable {
        var serialNumber: String
        var socLevel: Double?
        var temperature: Double?   // °C
        var power: Double?         // W
    }

    var electricLevel: Double?
    var solarInputPower: Double?
    var solarChannels: [Double] = []
    var outputHomePower: Double?
    var gridInputPower: Double?
    var packInputPower: Double?      // décharge batterie
    var outputPackPower: Double?     // charge batterie
    var offGridPower: Double?
    var acMode: Int?
    var inputLimit: Double?
    var outputLimit: Double?
    var socMin: Double?              // %
    var socMax: Double?              // %
    var deviceTemperature: Double?   // °C
    var remainOutMinutes: Double?
    var rssi: Double?
    var batteryVoltage: Double?      // V
    var serialNumber: String?
    var packs: [Pack] = []
    var lastUpdate: Date?

    /// `remainOutTime` : 59940 = estimation indisponible.
    private static let invalidRemainMinutes: Double = 59940

    /// Fusionne un payload JSON `properties/report` dans l'état.
    /// Le payload peut être `{"properties": {...}, "packData": [...]}` ou à
    /// plat selon le firmware.
    mutating func merge(payload root: [String: Any], at date: Date = .now) {
        let props = (root["properties"] as? [String: Any]) ?? root

        func num(_ key: String) -> Double? { Self.number(props[key]) }

        if let v = num("electricLevel") ?? num("socLevel") { electricLevel = v }
        if let v = num("solarInputPower") { solarInputPower = v }
        if let v = num("outputHomePower") { outputHomePower = v }
        if let v = num("gridInputPower") { gridInputPower = v }
        if let v = num("packInputPower") { packInputPower = v }
        if let v = num("outputPackPower") { outputPackPower = v }
        if let v = num("gridOffPower") ?? num("offGridPower") { offGridPower = v }
        if let v = num("acMode") { acMode = Int(v) }
        if let v = num("inputLimit") { inputLimit = v }
        if let v = num("outputLimit") { outputLimit = v }
        if let v = num("minSoc") { socMin = Self.autoScaleSoc(v, directMax: 50) }
        if let v = num("socSet") { socMax = Self.autoScaleSoc(v, directMax: 100) }
        if let v = num("hyperTmp") { deviceTemperature = Self.kelvinTenthsToCelsius(v) }
        if let v = num("rssi") { rssi = v }
        if let v = num("BatVolt") { batteryVoltage = v / 100 }
        if let v = num("remainOutTime") {
            remainOutMinutes = v >= Self.invalidRemainMinutes ? nil : v
        }
        if let sn = (root["sn"] as? String) ?? (props["sn"] as? String) { serialNumber = sn }

        // Canaux solaires solarPower1…solarPower6 — tableau dense jusqu'au
        // dernier canal présent dans CE payload, canaux existants conservés.
        var channels = solarChannels
        for i in 1...6 {
            if let v = num("solarPower\(i)") {
                while channels.count < i { channels.append(0) }
                channels[i - 1] = v
            }
        }
        solarChannels = channels

        if let packArray = root["packData"] as? [[String: Any]] ?? props["packData"] as? [[String: Any]] {
            mergePacks(packArray)
        }

        lastUpdate = date
    }

    private mutating func mergePacks(_ packArray: [[String: Any]]) {
        for entry in packArray {
            guard let sn = entry["sn"] as? String, !sn.isEmpty else { continue }
            var pack = packs.first(where: { $0.serialNumber == sn }) ?? Pack(serialNumber: sn)
            func num(_ key: String) -> Double? { Self.number(entry[key]) }
            if let v = num("socLevel") { pack.socLevel = v }
            if let v = num("power") { pack.power = v }
            if let v = num("maxTemp") { pack.temperature = Self.kelvinTenthsToCelsius(v) }
            if let idx = packs.firstIndex(where: { $0.serialNumber == sn }) {
                packs[idx] = pack
            } else {
                packs.append(pack)
            }
        }
    }

    /// Instantané complet au format `DeviceState` local — c'est ce que
    /// `Monitor.refresh()` consomme, à l'identique du mode API locale.
    func deviceState(fallbackSerial: String?) -> DeviceState {
        var state = DeviceState()
        state.solarInputPower = solarInputPower ?? 0
        state.solarChannels = solarChannels
        state.electricLevel = electricLevel
        state.outputHomePower = outputHomePower ?? 0
        state.gridInputPower = gridInputPower ?? 0
        state.packInputPower = packInputPower ?? 0
        state.outputPackPower = outputPackPower ?? 0
        state.offGridPower = offGridPower ?? 0
        state.serialNumber = serialNumber ?? fallbackSerial
        state.packs = packs.map {
            PackInfo(serialNumber: $0.serialNumber, socLevel: $0.socLevel,
                     temperature: $0.temperature, power: $0.power)
        }
        state.acMode = acMode
        state.inputLimit = inputLimit
        state.outputLimit = outputLimit
        state.deviceTemperature = deviceTemperature
        state.remainOutMinutes = remainOutMinutes
        state.rssi = rssi
        state.batteryVoltage = batteryVoltage
        state.socMax = socMax
        state.socMin = socMin
        state.updatedAt = lastUpdate ?? .now
        return state
    }

    // MARK: - Conversions et parsing tolérant

    /// Les nombres arrivent indifféremment en Int, Double, NSNumber ou String
    /// selon le firmware.
    static func number(_ value: Any?) -> Double? {
        switch value {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }

    /// Dixièmes de kelvin → °C (`hyperTmp: 2981` = 25 °C).
    static func kelvinTenthsToCelsius(_ raw: Double) -> Double {
        (raw - 2731) / 10
    }

    /// `socSet`/`minSoc` : deux échelles observées selon la source (80 ou 800).
    /// `directMax` = maximum réglable du champ en % (100 pour socSet, 50 pour
    /// minSoc) : au-delà, la valeur est forcément en dixièmes — ainsi
    /// `minSoc: 100` (dixièmes, firmware SolarFlow) donne bien 10 %.
    static func autoScaleSoc(_ raw: Double, directMax: Double) -> Double {
        raw > directMax ? raw / 10 : raw
    }
}
