import Foundation

/// Cumuls d'une journée de production, en logique pure (testable sans Monitor) :
/// intégration W→Wh avec pas borné, bascule de jour, courbe 5 min et pic.
/// L'appelant fournit `dayKey` et `minuteOfDay` (fuseau local) pour garder la
/// struct indépendante de Calendar/DateFormatter.
struct DailyAccumulator: Equatable {
    private(set) var day: String
    private(set) var solarWh: Double
    private(set) var storedWh: Double
    private(set) var gridWh: Double
    private(set) var curve: [Double]      // max par tranche de 5 min
    private(set) var peakW: Double
    private(set) var lastSampleAt: Date?

    init(day: String, solarWh: Double = 0, storedWh: Double = 0, gridWh: Double = 0,
         curve: [Double] = [], peakW: Double = 0) {
        self.day = day
        self.solarWh = solarWh
        self.storedWh = storedWh
        self.gridWh = gridWh
        self.curve = curve
        self.peakW = peakW
    }

    /// Intègre un échantillon de flux. Retourne true si le jour a basculé
    /// (l'appelant remet alors ses compteurs persistés à zéro).
    @discardableResult
    mutating func ingest(solar: Double, charge: Double, gridIn: Double,
                         at date: Date, dayKey: String, minuteOfDay: Int,
                         maxDt: TimeInterval) -> Bool {
        var rolled = false
        if dayKey != day {
            self = DailyAccumulator(day: dayKey)
            rolled = true
        }
        if let last = lastSampleAt {
            // dt borné : un réveil de machine ne crédite pas des heures de veille.
            let dt = min(date.timeIntervalSince(last), maxDt)
            if dt > 0 {
                solarWh += solar * dt / 3600
                storedWh += EnergyMath.solarToBattery(solar: solar, charge: charge,
                                                      gridIn: gridIn) * dt / 3600
                gridWh += gridIn * dt / 3600
            }
        }
        lastSampleAt = date

        let bucket = max(0, minuteOfDay) / 5
        if curve.count <= bucket {
            curve.append(contentsOf: Array(repeating: 0, count: bucket + 1 - curve.count))
        }
        curve[bucket] = max(curve[bucket], solar)
        peakW = max(peakW, solar)
        return rolled
    }

    /// Fusion avec le collecteur 24/7 : garde le meilleur des deux comptages.
    mutating func mergeSolarWh(_ wh: Double) {
        solarWh = max(solarWh, wh)
    }

    /// À appeler après un trou de mesure (erreur réseau) : le prochain
    /// échantillon ne créditera pas l'intervalle d'indisponibilité.
    mutating func resetSampleClock() {
        lastSampleAt = nil
    }
}
