# La fenêtre SunRoad (3D)

*Nouveau en 2.0.*

SunRoad met **ta maison, ton quartier et le soleil dans une vraie scène 3D** — inspirée de l'extension Home Assistant [Helios](https://github.com/ReikanYsora/helios), mais en 3D native : le soleil y est une véritable source de lumière, et les ombres portées sont réelles.

Ouvre-la avec le **cube indigo** dans l'en-tête du panneau. La fenêtre réutilise la position et les champs de panneaux configurés dans la [fenêtre Soleil](soleil.md).

## La scène

- **Le quartier** : les emprises des bâtiments (rayon 120 m) et les routes (170 m) viennent d'OpenStreetMap — hauteurs réelles quand la carte les connaît, largeur des voies selon leur classe (rue, départementale, chemin piéton…). **Ta maison est détectée automatiquement** (le bâtiment le plus proche de la position configurée) et surlignée en ambre. Le tout est mis en cache : un seul téléchargement, bouton ↻ pour recharger.
- **Le soleil, pour de vrai** : l'arc du jour (éphémérides NOAA calculées localement) avec un repère à chaque heure pleine, et le soleil comme **lumière directionnelle** — les ombres des bâtiments voisins tournent au fil de la journée, et tu vois si elles touchent tes panneaux.
- **Tes champs de panneaux** : posés avec leurs vrais azimut et inclinaison, dimensionnés d'après leur puissance crête.
- **Le ciel vivant** : nuit, aube, plein jour, crépuscule — et la **météo réelle** (Open-Meteo) : la couverture nuageuse voile la lumière et grise le ciel.

## L'énergie en direct

Des **billes animées** montrent les flux au rythme des watts mesurés : panneaux → maison (jaune), pylône réseau → maison (orange), maison ↔ batterie (vert en charge, orange en décharge). Le long de l'arc, un **ruban de production** dessine ta journée solaire : un bâton par quart d'heure, à l'endroit exact où le soleil se trouvait.

## Timeline ±48 heures

Le curseur en bas de la fenêtre déplace le temps de deux jours en arrière ou en avant : le soleil, les ombres, le ciel et l'arc suivent. Le bouton **Maintenant** revient au temps réel (la scène suit alors l'horloge, minute par minute).

## Couches et mode mur

Chaque couche s'active à la carte (checkboxes) : bâtiments, routes, arc du soleil, panneaux, boussole, énergie. Le bouton **œil barré** efface toute l'interface — idéal sur un écran d'appoint — et un œil discret la fait revenir.

## Bon à savoir

- La fidélité du quartier dépend d'OpenStreetMap : sans tag de hauteur, un bâtiment fait 6 m par défaut.
- Sans réseau (ou si Overpass est occupé), la scène reste utilisable avec une maison stylisée ; le quartier reviendra au prochain chargement.
- Glisser pour orbiter, molette pour zoomer.

---

[← La fenêtre Historique](historique.md) | [Index](../README.md) | [Les widgets →](widgets.md)
