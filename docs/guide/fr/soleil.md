---
title: La fenêtre Soleil
---

[🇬🇧 English version](../en/sun.md)

# La fenêtre Soleil

Ouvrez-la depuis l'icône **soleil orange** de l'en-tête du panneau. Elle réunit la course réelle du soleil, l'orientation de chacun de vos champs de panneaux, la production du jour, les éphémérides, la lumière, le productible théorique et la météo locale — **le tout sur un seul écran, sans défilement**.

![Fenêtre Soleil](../images/sun-light.png)

*La fenêtre Soleil : le bandeau d'indicateurs, le dôme céleste et le compas solaire, puis le détail par champ de panneaux, les éphémérides, le productible, la lumière et la météo.*

Les légendes sous chaque carte sont volontairement courtes : **survolez-les** pour obtenir l'explication complète en infobulle.

## Configurer votre position

La fenêtre a besoin de votre latitude et longitude : **Réglages → Soleil**, section **Position**. Deux façons de les renseigner :

- saisir les valeurs à la main ;
- cliquer sur le bouton d'utilisation de la **position du Mac** (localisation CoreLocation ponctuelle, avec l'accord de macOS).

![Onglet Soleil des réglages](../images/settings-sun.png)

*L'onglet Soleil : position, puis un champ de panneaux par orientation.*

Les éphémérides sont calculées **localement sur le Mac** (algorithme NOAA) : votre position ne quitte pas la machine pour ce calcul. Seule exception : si la carte météo est utilisée, les coordonnées (arrondies à 4 décimales) sont envoyées au service Open-Meteo pour obtenir la prévision.

## Décrire vos champs de panneaux

Dans **Réglages → Soleil**, section **Champs de panneaux**, ajoutez un champ par orientation de toiture. Pour chacun :

- un **nom** libre (« Toit sud-est », « Façade ouest »…) ;
- la **puissance crête** en Wc ;
- l'**azimut** : 0° = nord, 90° = est, 180° = plein sud, 270° = ouest — le curseur affiche le libellé cardinal correspondant ;
- l'**inclinaison** : 0° à plat, 30° pour une toiture courante, 90° en façade.

Si vous aviez seulement renseigné une puissance crête dans une version précédente, elle est reprise telle quelle comme un champ unique plein sud incliné à 30° : rien à ressaisir, mais ajustez l'orientation pour que les estimations collent à votre installation.

Supprimer tous vos champs ne perd pas votre puissance crête : elle reste enregistrée, et un champ unique plein sud vous est reproposé à la prochaine ouverture de l'onglet.

### Régler l'orientation depuis la fenêtre Soleil

Le nom du champ et sa puissance crête se saisissent dans les réglages, mais **l'azimut et l'inclinaison se règlent aussi directement dans la carte « Champs de panneaux » de la fenêtre Soleil** : deux curseurs par champ, le premier pour l'azimut, le second pour l'inclinaison. Le dôme, le compas, l'incidence et le productible suivent le geste — c'est la façon la plus rapide de trouver l'orientation qui correspond vraiment à votre toiture. Les valeurs sont enregistrées immédiatement, elles se retrouvent donc dans les réglages.

## Le héros : le dôme céleste

Le graphique du haut est une carte du ciel. La **hauteur** est l'élévation du soleil, la **largeur** son azimut (les repères E, SE, S, SO, O sont posés sur l'horizon) :

- le **trait plein** est la course du soleil aujourd'hui, avec un point par heure ; la portion déjà parcourue est vive, le reste du jour atténué ;
- les **pointillés** sont les courses des deux solstices — les bornes que le soleil ne franchit jamais chez vous ;
- la **zone jaune** est la production mesurée du jour, posée à l'endroit du ciel où se trouvait le soleil à cet instant ;
- les **losanges colorés** sont les directions que visent vos champs de panneaux, avec l'écart d'incidence du moment. Quand le soleil rejoint un losange, ce champ travaille à son maximum et son marqueur s'illumine ;
- le **ciel** change de couleur avec la hauteur du soleil : nuit étoilée, crépuscule, heure dorée, plein jour.

## Le compas solaire

Le même ciel, vu du dessus : le **centre est le zénith**, le **cercle extérieur l'horizon**, le nord en haut. On y lit la course du jour et celles des solstices, et surtout, autour de la direction visée par chaque champ, les **boucles d'iso-incidence à 25° et 50°** : la zone de ciel dans laquelle ce champ produit près de son optimum. Le soleil s'y déplace au fil de la journée.

## Champs de panneaux

Une ligne par champ, avec sa couleur :

- le **productible ciel clair** du champ à l'instant présent ;
- l'**incidence** du soleil sur ce champ, en degrés (0° = pile dans l'axe) ;
- une **barre** qui donne la part de l'irradiance crête réellement captée ;
- la **meilleure heure** du jour pour ce champ, et le **potentiel du jour** en kWh.

En pied de carte : le total ciel clair, la production mesurée et la puissance crête installée.

## Éphémérides

Lever, coucher, **midi solaire** (avec le temps restant), durée du jour, **écart de durée du jour depuis hier** à la seconde, élévation actuelle et maximale, et le **prochain solstice ou équinoxe** avec son compte à rebours.

## Lumière et crépuscules

Les **aubes** et **crépuscules** civil (−6°), nautique (−12°) et astronomique (−18°), et les deux **heures dorées** — les plages où le soleil est sous 6° d'élévation.

## Productible théorique

- **Ciel clair maintenant** — la somme du productible de tous vos champs ;
- **Production mesurée** et **rendement estimé** ;
- **Énergie ciel clair du jour** contre **énergie mesurée du jour**, et la **part du potentiel** atteinte ;
- **Masse d'air** traversée et **longueur d'ombre** d'un objet d'une unité de haut.

Le modèle : 85 % de rayonnement direct, pondéré par l'incidence sur chaque champ et par la traversée d'atmosphère (loi de Meinel), 15 % de diffus selon la part de ciel vue par le panneau, moins 10 % de pertes onduleur et câblage. Il ne connaît ni la météo ni vos ombrages.

## Météo locale

La météo vient d'**Open-Meteo** (service gratuit, sans compte ni clé d'API), rafraîchie au plus toutes les 30 minutes :

- conditions actuelles (ciel clair, nuageux, pluie…) et température ;
- **couverture nuageuse** en pourcentage et **facteur nuages** appliqué ;
- **ensoleillement prévu** aujourd'hui ;
- **productible ajusté nuages** — le théorique ciel clair atténué par la couverture nuageuse (formule de Kasten–Czeplak : facteur 1 − 0,75 × C^3,4, soit au minimum 25 % du théorique sous un ciel entièrement couvert).

---

[← Le tableau de bord](tableau-de-bord.md) | [Index](../README.md) | [Les widgets →](widgets.md)
