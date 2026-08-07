import Foundation

/// Détection de panne, logique pure (testée sans réseau ni horloge réelle) :
/// - appareil injoignable depuis un certain temps ;
/// - production et injection nulles alors que le soleil est haut.
///
/// Née de l'incident du 2026-08-07 : SolarFlow en défaut (batterie pleine,
/// injection coupée) puis hors réseau — l'app affichait « Hors ligne » en
/// silence et aucune alerte n'existait pour ce cas.
struct OutageWatchdog {
    enum Event: Equatable {
        case unreachable(since: Date)
        case productionAnomaly(since: Date)
    }

    /// Silence réseau toléré avant l'alerte « injoignable » (s).
    var unreachableAfter: TimeInterval
    /// Durée de production nulle en plein jour avant l'alerte « anomalie » (s).
    var anomalyAfter: TimeInterval
    /// Élévation solaire (°) au-dessus de laquelle produire est attendu.
    var minElevation: Double
    /// Puissance (W) sous laquelle production et injection comptent pour nulles.
    var idleWatts: Double

    private(set) var lastContact: Date
    private(set) var unreachableNotified = false
    private(set) var anomalyStart: Date?
    private(set) var anomalyNotified = false

    init(unreachableAfter: TimeInterval = 600,
         anomalyAfter: TimeInterval = 1800,
         minElevation: Double = 20,
         idleWatts: Double = 10,
         startedAt: Date = .now) {
        self.unreachableAfter = unreachableAfter
        self.anomalyAfter = anomalyAfter
        self.minElevation = minElevation
        self.idleWatts = idleWatts
        self.lastContact = startedAt
    }

    /// Vrai dès que le silence réseau dépasse le seuil (état ⚠️ de la barre
    /// de menu) — indépendant du fait que la notification soit déjà partie.
    func isOffline(at date: Date) -> Bool {
        date.timeIntervalSince(lastContact) >= unreachableAfter
    }

    /// À appeler sur chaque poll en échec. Retourne l'évènement à notifier
    /// (une seule fois par épisode de coupure).
    mutating func pollFailed(at date: Date) -> Event? {
        guard isOffline(at: date), !unreachableNotified else { return nil }
        unreachableNotified = true
        return .unreachable(since: lastContact)
    }

    /// À appeler sur chaque poll réussi. `elevation` : élévation solaire
    /// actuelle en degrés (passer une valeur négative pour désactiver la
    /// détection d'anomalie, ex. position non configurée).
    mutating func deviceResponded(solarW: Double, homeW: Double,
                                  elevation: Double, at date: Date) -> Event? {
        lastContact = date
        unreachableNotified = false

        guard elevation >= minElevation, solarW < idleWatts, homeW < idleWatts else {
            anomalyStart = nil
            anomalyNotified = false
            return nil
        }
        let start = anomalyStart ?? date
        anomalyStart = start
        guard date.timeIntervalSince(start) >= anomalyAfter, !anomalyNotified else { return nil }
        anomalyNotified = true
        return .productionAnomaly(since: start)
    }
}
