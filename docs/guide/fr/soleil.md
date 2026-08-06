---
title: La fenêtre Soleil
---

[🇬🇧 English version](../en/sun.md)

# La fenêtre Soleil

Ouvrez-la depuis l'icône **soleil orange** de l'en-tête du panneau. Elle réunit, sans défilement, la course du soleil, la production du jour, les éphémérides, le productible théorique et la météo locale.

![Fenêtre Soleil](../images/sun-light.png)

*La fenêtre Soleil : le graphique héros en haut, puis trois colonnes — éphémérides, productible, météo.*

## Configurer votre position

La fenêtre a besoin de votre latitude et longitude : **Réglages → Soleil**, section **Position**. Deux façons de les renseigner :

- saisir les valeurs à la main ;
- cliquer sur le bouton d'utilisation de la **position du Mac** (localisation CoreLocation ponctuelle, avec l'accord de macOS).

![Onglet Soleil des réglages](../images/settings-sun.png)

*L'onglet Soleil : position et puissance crête des panneaux.*

Les éphémérides sont calculées **localement sur le Mac** (algorithme NOAA) : votre position ne quitte pas la machine pour ce calcul. Seule exception : si la carte météo est utilisée, les coordonnées (arrondies à 4 décimales) sont envoyées au service Open-Meteo pour obtenir la prévision.

## Le graphique héros : course du soleil × production

- L'**arc pointillé** représente la trajectoire du soleil entre le lever et le coucher, avec l'icône ☀️ à sa position actuelle.
- La **zone jaune** est la production mesurée aujourd'hui (le maximum de chaque tranche de 5 minutes), sur le même axe temporel.

D'un regard, vous voyez si la production suit la course du soleil ou si des nuages (ou des ombres) la creusent.

## Colonne Éphémérides

Lever, coucher, **midi solaire**, durée du jour, **élévation** actuelle (et maximale du jour) et **azimut** du soleil.

## Colonne Productible théorique

Renseignez la **puissance crête** de vos panneaux (Wc) dans **Réglages → Soleil**, section Panneaux. La carte affiche alors :

- **Théorique ciel clair** — puissance crête × sin(élévation) × 0,9, un modèle simple sans météo ni orientation des panneaux ;
- **Production mesurée** — la puissance réelle du moment ;
- **Rendement estimé** — le rapport des deux, en pourcentage.

## Colonne Météo locale

La météo vient d'**Open-Meteo** (service gratuit, sans compte ni clé d'API), rafraîchie au plus toutes les 30 minutes :

- conditions actuelles (ciel clair, nuageux, pluie…) et température ;
- **couverture nuageuse** en pourcentage ;
- **ensoleillement prévu** aujourd'hui ;
- **productible ajusté nuages** — le théorique ciel clair atténué par la couverture nuageuse (formule de Kasten–Czeplak : facteur 1 − 0,75 × C^3,4, soit au minimum 25 % du théorique sous un ciel entièrement couvert).

---

[← Le tableau de bord](tableau-de-bord.md) | [Index](../README.md) | [Les widgets →](widgets.md)
