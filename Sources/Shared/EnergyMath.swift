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
}
