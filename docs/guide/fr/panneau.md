---
title: Le panneau
---

[🇬🇧 English version](../en/panel.md)

# Le panneau de la barre de menu

Cliquez sur l'icône ☀️ pour ouvrir le panneau : cinq cartes qui résument l'essentiel en un coup d'œil.

Depuis la 1.11, chaque carte se **replie d'un clic sur son en-tête** (chevron à droite) : repliée, elle ne garde qu'une ligne avec sa valeur clé — production en W, batterie en %, flux maison en W, consommation totale en W, total 14 jours en kWh. L'état est mémorisé carte par carte. Et chaque carte peut être **masquée entièrement** dans *Réglages → Affichage → Cartes du panneau*.

![Panneau, thème clair](../images/panel-light.png)

*Le panneau en thème clair : production, batterie, flux et historique.*

![Panneau, thème sombre](../images/panel-dark.png)

*Le même panneau en thème sombre.*

## L'en-tête

En haut du panneau : le nom de l'application, l'heure de la dernière mise à jour, et six actions en icônes :

- **Jauge bleue** — ouvre le [tableau de bord](tableau-de-bord.md) ;
- **Soleil orange** — ouvre la [fenêtre Soleil](soleil.md) ;
- **Horloge violette** — ouvre la [fenêtre Historique](historique.md) *(1.12)* ;
- **Cube indigo** — ouvre la [fenêtre SunRoad](sunroad.md) en 3D *(2.0)* ;
- **Engrenage turquoise** — ouvre les Réglages ;
- **⋯** — menu avec **Rechercher des mises à jour…** et **Quitter Zendure Monitor**.

Astuce : un **double-clic sur n'importe quel graphique** du panneau ouvre le tableau de bord.

## Carte Production solaire

- La **puissance instantanée** en grand, et l'**énergie produite aujourd'hui** (kWh) à droite.
- Un graphique dont la période se choisit avec le sélecteur **15 min / Jour / 14 j** :
  - **15 min** — sparkline des derniers relevés ;
  - **Jour** — courbe de la production du jour (le maximum de chaque tranche de 5 minutes, conservé même si vous relancez l'application) ;
  - **14 j** — histogramme de l'énergie des 14 derniers jours.
- Si la batterie a plusieurs entrées MPPT, chaque **Entrée PV** est détaillée avec sa puissance.

## Carte Batterie

- Une **jauge circulaire** du niveau de charge (SOC), avec la mention « charge » ou « décharge » au centre quand un flux est actif. La couleur suit le niveau : rouge sous 15 %, orange sous 40 %, vert au-delà.
- Les lignes **Charge** et **Décharge** avec la puissance du flux, et une sparkline du flux batterie (vert en charge, orange en décharge).
- Une ligne par **pack** physique : SOC, température et puissance.

## Carte Flux

- **Vers la maison** — la puissance envoyée à votre installation.
- **Depuis le réseau** — la puissance tirée du réseau public.
- Une sparkline de la consommation envoyée à la maison.
- La **répartition solaire du jour** : « X % direct · Y % stocké » — la part de la production partie directement vers la maison et la part qui a chargé la batterie (la charge depuis le secteur, par exemple en heures creuses, est déduite du calcul). Le cumul **Réseau** du jour s'affiche à droite dès qu'il est significatif.

## Carte Consommation maison

*Nouvelle en 1.10.3.*

- Avec un [compteur Smart CT](cloud.md#le-compteur-smart-ct) configuré : la **consommation totale de la maison** en grand — le soutirage réseau mesuré au tableau (la charge secteur du SolarFlow, que le compteur voit passer aussi, est déduite) plus l'injection du SolarFlow — avec le détail par source : **Depuis le SolarFlow** et **Depuis le réseau**.
- Sans compteur : seule l'injection du SolarFlow est affichée (« via SolarFlow seulement »), avec une invitation à renseigner le Smart CT.
- Si le compteur est configuré mais **injoignable** (typiquement à distance : il n'est lisible que sur le réseau local), la carte le dit explicitement — la valeur est marquée partielle plutôt que de laisser croire qu'aucun compteur n'existe.

## Carte Historique

- L'histogramme des **14 derniers jours** avec le total de la période.
- Le bouton de partage exporte tout l'historique conservé (jusqu'à 90 jours) en **CSV** (colonnes `date,wh`).
- En dessous : le **pic** de puissance du jour et la comparaison **vs hier** en pourcentage.

## Hors ligne : les valeurs restent affichées

Si la batterie ne répond plus (coupure réseau, appareil éteint), le panneau ne se vide pas : les dernières valeurs restent affichées, **grisées**, et l'en-tête indique « Hors ligne — dernières données à HH:MM:SS ». Des bandeaux d'avertissement apparaissent en bas du panneau selon la situation : connexion via l'hôte de secours, erreur réseau, accès au réseau local bloqué, notifications refusées.

## Options de la barre de menu

Dans **Réglages → Affichage**, choisissez ce que la barre de menu affiche à côté de l'icône :

- **Production solaire (W)** — activé par défaut ;
- **Niveau de batterie (%)** ;
- **Consommation maison (W)**.

Tout décocher n'affiche que l'icône ☀️. Le même onglet propose la section **Cartes du panneau** (afficher ou masquer chacune des cinq cartes) et le **thème** : Auto (suit macOS), Sombre ou Clair.

---

[← Premiers pas](demarrage.md) | [Index](../README.md) | [Le tableau de bord →](tableau-de-bord.md)
