# Zendure Monitor 1.6.0

## Nouveautés
- **Répartition solaire du jour** : le panneau (carte Flux) et le tableau de bord (carte Production solaire) affichent « Solaire du jour : X % direct · Y % stocké », plus le cumul tiré du réseau. La part stockée déduit la charge secteur (heures creuses) du calcul.

## Corrections
- Le panneau ne retombe plus sur « Pas de données » en cas de coupure réseau : les dernières valeurs restent affichées, grisées, avec l'heure des dernières données.
- Accès distant (VPN) : une fois basculé sur l'hôte de secours, l'app y reste et ne reteste l'hôte principal que toutes les 2 minutes — les rafraîchissements ne payent plus un timeout de 5 s à chaque poll.
- La saisie de l'adresse du device et le réglage de l'intervalle ne relancent plus le polling à chaque frappe.
- Les compteurs du jour basculent désormais à minuit (heure locale) et non plus à minuit UTC.
- Icônes d'action de l'en-tête du panneau colorées (tableau de bord, Soleil, réglages) pour une meilleure visibilité.
- Version du widget alignée sur celle de l'app ; nettoyage des derniers avertissements de compilation.

## Qualité
- Nouvelle logique de flux extraite et testée (20 tests unitaires, CI verte).
