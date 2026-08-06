import Foundation

/// Répartition de la production solaire à partir des flux instantanés du hub.
/// Bilan : solaire + réseau + décharge = maison + charge + hors-réseau (+ pertes).
/// Le hub ne mesure pas la consommation de la maison — on ne peut donc pas
/// calculer un vrai taux d'autoconsommation, mais la part de la production
/// stockée vs envoyée directement est déductible des flux.
enum EnergyMath {
    /// Puissance de charge batterie couverte par le solaire : la charge AC
    /// (heures creuses) est alimentée par le réseau en premier, le reste
    /// vient du solaire, borné par la production.
    static func solarToBattery(solar: Double, charge: Double, gridIn: Double) -> Double {
        max(0, min(solar, charge - gridIn))
    }

    /// Part stockée de la production du jour (0…1) — nil tant que la
    /// production est trop faible pour que le ratio ait un sens.
    static func storedShare(storedWh: Double, solarWh: Double) -> Double? {
        guard solarWh >= 1 else { return nil }
        return min(storedWh / solarWh, 1)
    }

    /// Facteur d'atténuation nuageuse de Kasten–Czeplak (1980) :
    /// G = G_clair × (1 − 0,75 × (C/8)^3,4), C en octas — ici la couverture
    /// arrive en % (0–100). Plancher naturel : 0,25 à ciel entièrement couvert.
    static func cloudFactor(coverPercent: Double) -> Double {
        let cover = min(max(coverPercent / 100, 0), 1)
        return 1 - 0.75 * pow(cover, 3.4)
    }
}
