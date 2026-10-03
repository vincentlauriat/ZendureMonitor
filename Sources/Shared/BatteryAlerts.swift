import Foundation

/// Alertes batterie faible / pleine, logique pure et PAR APPAREIL : avec
/// plusieurs SolarFlow, la moyenne masque un appareil vide (10 % + 100 %
/// = 55 %, aucune alerte). Chaque alerte part une fois par épisode et se
/// réarme avec une hystérésis de 5 points.
struct BatteryAlerts {
    enum Event: Equatable {
        case low
        case full
    }

    private var lowNotified: Set<String> = []
    private var fullNotified: Set<String> = []

    /// `socMax` : plafond de charge de l'appareil (pleine = atteint), 100 %
    /// s'il est inconnu.
    mutating func evaluate(id: String, soc: Double, socMax: Double?, lowThreshold: Double) -> [Event] {
        var events: [Event] = []
        if soc <= lowThreshold {
            if lowNotified.insert(id).inserted { events.append(.low) }
        } else if soc > lowThreshold + 5 {
            lowNotified.remove(id)
        }
        let target = min(socMax ?? 100, 100)
        if soc >= target - 0.5 {
            if fullNotified.insert(id).inserted { events.append(.full) }
        } else if soc < target - 5 {
            fullNotified.remove(id)
        }
        return events
    }

    /// Oublie les appareils retirés des réglages.
    mutating func keep(ids: Set<String>) {
        lowNotified.formIntersection(ids)
        fullNotified.formIntersection(ids)
    }
}
