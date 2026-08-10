# La fenêtre Historique

*Nouveau en 1.12.*

Jusqu'ici, l'app ne connaissait que ce qu'elle avait vu elle-même (ou via le collecteur 24/7). La fenêtre **Historique** va chercher l'énergie quotidienne **sur les serveurs Zendure** — jusqu'à **365 jours** en arrière, même pour les périodes où votre Mac était éteint.

Ouvrez-la avec l'**horloge violette** dans l'en-tête du panneau.

## Connexion au compte Zendure

L'historique passe par l'API privée de l'app mobile Zendure — la seule voie connue vers ces données. Elle exige l'**e-mail et le mot de passe du compte principal Zendure** (ceux de l'app sur votre téléphone) : le Cloud Key du [mode Cloud](cloud.md) ne suffit pas.

- Les identifiants sont stockés **uniquement dans le trousseau macOS**, sur un chemin totalement séparé du Cloud Key.
- Le bouton **Déconnecter le compte** les efface du trousseau à tout moment.
- Aucun mode Cloud n'est requis : l'historique fonctionne aussi bien en **mode local** qu'en mode Cloud.

## Ce que la fenêtre affiche

Une carte par appareil du compte (SolarFlow Hub, Hyper…), chacune avec :

- un **graphique en barres** de l'énergie quotidienne (kWh) sur **7 / 30 / 90 / 365 jours** (sélecteur en haut de la fenêtre) ;
- un **sélecteur de métrique propre à l'appareil** : chaque produit renvoie sa propre liste de champs (solaire, maison, charge/décharge batterie, réseau, sortie AC/DC…) — la liste ne propose que ce que *votre* appareil renvoie réellement, et le choix est mémorisé par appareil ;
- **Total période, moyenne par jour, meilleur jour** sous le graphique ;
- les **totaux vie entière** de l'appareil.

## Cache local et rythme des requêtes

Les jours passés sont immuables : une fois récupérés, ils sont **mis en cache sur le Mac** et ne sont jamais re-téléchargés — seul le jour courant est rafraîchi. Le premier chargement de 365 jours prend environ une minute (les requêtes sont volontairement espacées pour ménager les serveurs Zendure) ; ensuite, l'actualisation est quasi instantanée.

## La carte Débogage

En bas de la fenêtre, la carte **Débogage** liste les derniers échanges HTTP avec l'API (mot de passe masqué) : statut, requête et réponse brute, dépliables et copiables. C'est le premier endroit à regarder si la connexion échoue.

## Bon à savoir

Cette API n'est **pas contractuelle** : les noms des champs et les unités (supposées en Wh) viennent d'observations communautaires (module FHEM Zendure, solarflow-statuspage). Zendure peut la faire évoluer sans préavis — la carte Débogage est là pour comprendre ce qui a changé le cas échéant.

---

[← Le tableau de bord](tableau-de-bord.md) | [Index](../README.md) | [La fenêtre SunRoad →](sunroad.md)
