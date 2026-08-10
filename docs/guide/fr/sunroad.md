# La fenêtre SunRoad (3D)

*Nouveau en 2.0.*

SunRoad met **ta maison, ton quartier et le soleil dans une vraie scène 3D** — inspirée de l'extension Home Assistant [Helios](https://github.com/ReikanYsora/helios), mais en 3D native : le soleil y est une véritable source de lumière, et les ombres portées sont réelles.

Ouvre-la avec le **soleil orange** dans l'en-tête du panneau. Depuis la 2.0, SunRoad **remplace l'ancienne fenêtre Soleil** : le dôme céleste et le compas solaire cèdent la place à la scène 3D, et tout le reste (éphémérides, productible, météo, sliders d'orientation) vit dans un **panneau latéral** repliable. La position et les champs de panneaux se configurent dans *Réglages → Soleil*.

## La scène

- **Le quartier** : les emprises des bâtiments (rayon 120 m) et les routes (170 m) viennent d'OpenStreetMap — hauteurs réelles quand la carte les connaît, largeur des voies selon leur classe (rue, départementale, chemin piéton…). **Ta maison est détectée automatiquement** (le bâtiment le plus proche de la position configurée) et surlignée en ambre. Le tout est mis en cache : un seul téléchargement, bouton ↻ pour recharger.
- **Le soleil, pour de vrai** : l'arc du jour (éphémérides NOAA calculées localement) avec un repère à chaque heure pleine, et le soleil comme **lumière directionnelle** — les ombres des bâtiments voisins tournent au fil de la journée, et tu vois si elles touchent tes panneaux.
- **Tes champs de panneaux** : posés avec leurs vrais azimut et inclinaison, dimensionnés d'après leur puissance crête.
- **Le ciel vivant** : nuit, aube, plein jour, crépuscule — et la **météo réelle** (Open-Meteo) : la couverture nuageuse voile la lumière et grise le ciel.

## L'énergie en direct

Des **billes animées** montrent les flux au rythme des watts mesurés : panneaux → maison (jaune), pylône réseau → maison (orange), maison ↔ batterie (vert en charge, orange en décharge). Le long de l'arc, un **ruban de production** dessine ta journée solaire : un bâton par quart d'heure, à l'endroit exact où le soleil se trouvait.

## Timeline ±48 heures

Le curseur en bas de la fenêtre déplace le temps de deux jours en arrière ou en avant : le soleil, les ombres, le ciel et l'arc suivent. Le bouton **Maintenant** revient au temps réel (la scène suit alors l'horloge, minute par minute).

## Le panneau latéral (hérité de la fenêtre Soleil)

À droite de la scène, des cartes repliables :

- **Champs de panneaux** — chaque champ avec ses **curseurs d'azimut et d'inclinaison** : le panneau pivote dans la scène 3D pendant le geste, l'incidence, le productible et la meilleure heure suivent.
- **Production** — le total du jour et l'**histogramme des 14 derniers jours**.
- **Éphémérides** et **Lumière et crépuscules** — lever/coucher, midi solaire, durée du jour, aubes et crépuscules, heures dorées, prochain solstice ou équinoxe.
- **Productible théorique** — ciel clair instantané et du jour, rendement estimé face à la production mesurée, masse d'air, longueur d'ombre.
- **Météo locale** — conditions, couverture nuageuse et productible ajusté nuages.

Le bouton de barre latérale dans le HUD masque tout le panneau pour une scène plein cadre.

## Définir ta maison au clic

Le centre de la scène est la position des réglages — souvent approximative. Le menu **maison** du HUD propose **« Définir ma maison »** : clique sur le bon bâtiment dans la scène, son emprise devient le centre exact — la détection, la projection et les éphémérides se recalent dessus (et le quartier se recharge autour). « Revenir à la position des réglages » annule à tout moment.

## Couches et mode mur

Chaque couche s'active à la carte (checkboxes) : bâtiments, routes, arc du soleil, panneaux, boussole, énergie. Le bouton **œil barré** efface toute l'interface — idéal sur un écran d'appoint — et un œil discret la fait revenir.

## Bon à savoir

- La fidélité du quartier dépend d'OpenStreetMap : sans tag de hauteur, un bâtiment fait 6 m par défaut.
- Sans réseau (ou si Overpass est occupé), la scène reste utilisable avec une maison stylisée ; le quartier reviendra au prochain chargement.
- Glisser pour orbiter, molette pour zoomer.

---

[← La fenêtre Historique](historique.md) | [Index](../README.md) | [Les widgets →](widgets.md)
