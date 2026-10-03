# PRD — Zendure Monitor

**Produit :** Zendure Monitor — application macOS de barre de menus pour batterie solaire Zendure SolarFlow
**Version documentée :** 2.2.0 (build 22) — état livré au 2026-08-13
**Auteur :** Vincent Lauriat · **Dépôt :** [github.com/vincentlauriat/ZendureMonitor](https://github.com/vincentlauriat/ZendureMonitor) (MIT, public)
**Statut :** produit en production, distribué publiquement, 22 versions livrées
**Dernière mise à jour :** 2026-08-14

> Ce PRD est **rétroactif et prospectif** : il formalise le produit tel qu'il est réellement livré (§1–§10) et cadre ce qui vient (§11–§14). Il fait référence pour arbitrer le périmètre ; `PLAN.md` porte le découpage d'exécution, `TODOS.md` l'avancement, `MEMORY.md` l'état et les décisions vécues.

---

## 1. Résumé exécutif

Zendure Monitor affiche la **production solaire en direct** d'une batterie Zendure SolarFlow dans la barre de menus macOS, et donne accès en un clic à l'état complet de l'installation : charge de la batterie, flux d'énergie, consommation de la maison, historique, et une scène 3D du soleil sur le quartier.

Sa proposition de valeur tient en un mot : **local-first**. L'app lit l'API zenSDK exposée par l'appareil sur le réseau local — sans compte, sans broker, sans identifiants, sans dépendance à une infrastructure tierce. Le mode Cloud existe, mais comme *repli optionnel*, jamais comme prérequis.

Le produit est mature : 46 fichiers Swift, 113 tests unitaires verts, CI GitHub Actions, DMG signé Developer ID et notarisé, auto-update Sparkle, guide utilisateur FR/EN en 12 pages, landing page publique.

---

## 2. Contexte et problème

### 2.1 Le problème utilisateur

Un propriétaire de SolarFlow dispose de l'application mobile Zendure. Celle-ci a trois défauts pour un usage quotidien depuis un poste de travail :

| Friction | Conséquence |
|---|---|
| Elle est sur le téléphone | Consulter sa production demande de sortir le téléphone, déverrouiller, ouvrir l'app, attendre |
| Elle passe par le cloud Zendure | Latence, dépendance à un service tiers, données de la maison qui transitent par des serveurs distants |
| Elle est conçue pour le pilotage, pas pour la veille | Aucun affichage ambiant, aucune notion de « je regarde du coin de l'œil pendant que je travaille » |

Le besoin réel n'est pas « une app de plus » : c'est un **affichage ambiant permanent**, à coût cognitif nul, sur l'écran où l'utilisateur passe déjà sa journée.

### 2.2 L'opportunité technique

Les firmwares récents Zendure embarquent un serveur HTTP sur le port 80 (`GET /properties/report`), documenté officiellement par [Zendure/zenSDK](https://github.com/Zendure/zenSDK), qui renvoie **tout l'état de l'appareil en un seul JSON**, sans authentification sur le LAN. L'intégration Home Assistant communautaire a prouvé la viabilité de cette voie. Elle rend possible un produit 100 % local, sans compte et sans secret à gérer.

### 2.3 Les alternatives existantes

- **App mobile Zendure** — officielle, complète, mais cloud-only et mobile-only.
- **Home Assistant + intégration zenSDK** — puissante, mais impose de faire tourner et maintenir une instance HA. Surdimensionnée pour « voir sa production ».
- **Rien sur macOS.** C'est le créneau.

---

## 3. Vision et principes directeurs

> **Voir sa production solaire doit coûter zéro geste.**

Cinq principes tranchent les arbitrages du produit. Ils sont non négociables : toute fonctionnalité qui en violerait un est refusée, quel que soit son intérêt.

**P1 — Local d'abord.** Le chemin par défaut ne demande ni compte, ni clé, ni internet. Le cloud est un repli explicite et opt-in.

**P2 — Lecture seule par défaut.** L'app pilote une vraie batterie domestique. L'écriture (`POST /properties/write`) existe mais est cantonnée à un onglet Contrôle dédié, **local uniquement**, jamais accessible depuis le mode Cloud.

**P3 — Honnêteté des données.** Une valeur non mesurée n'est jamais inventée ni silencieusement remplacée par zéro. C'est le principe le plus structurant du produit — il a produit trois décisions visibles :
- sans Smart CT, l'arc réseau→maison est explicitement marqué « non mesuré » ;
- dans le Sankey, le soutirage non mesuré garde une bande **hachurée d'épaisseur fixe hors échelle** (une largeur proportionnelle inventerait un chiffre, l'omettre affirmerait zéro) ;
- le déséquilibre du hub est dessiné comme un ruban gris nommé « Pertes & conversion », jamais absorbé en silence.

**P4 — Zéro dépendance superflue.** Swift/SwiftUI pur. Une seule dépendance tierce : Sparkle (mise à jour). Le client MQTT est écrit sur Network.framework plutôt qu'importé.

**P5 — Une vue qui compile n'est pas une vue qui marche.** Toute vue graphique est **rendue et regardée** avant d'être déclarée finie. Leçon payée trois fois (éditeur de champs éclaté dans un `Form`, hachures dégénérées en dalles dans le Sankey, libellés chevauchés) — la relecture de code ne détecte pas ces défauts.

---

## 4. Utilisateurs cibles

### Persona principal — « le propriétaire équipé »

Possède un SolarFlow depuis peu, travaille sur Mac, veut savoir en permanence ce que produit son installation et si sa batterie se charge. Techniquement à l'aise (sait lire une IP), mais **ne veut pas administrer un serveur**. Il installe un DMG et ça marche.

*Ce qu'il attend :* un chiffre dans la barre de menus, un panneau qui répond à « où va mon énergie en ce moment ? », et rien à maintenir.

### Persona secondaire — « l'optimiseur »

Même profil, un cran plus loin : il a ajouté un Smart Meter 3CT, connaît l'azimut de ses panneaux, veut comprendre l'écart entre production attendue et réelle, et arbitrer ses usages. C'est lui qui utilise SunRoad, l'Historique et les courbes de prévision.

### Persona tertiaire — « l'utilisateur nomade »

En déplacement, veut garder un œil sur son installation. Adressé par deux chemins : hôte de secours via VPN (Tailscale), ou bascule automatique vers le mode Cloud.

### Non-cibles explicites

- Utilisateurs Windows/Linux (macOS uniquement, `MenuBarExtra` natif).
- Installations multi-onduleurs hétérogènes / usage professionnel.
- Utilisateurs cherchant un système domotique complet — Home Assistant fait cela mieux.

---

## 5. Périmètre

### 5.1 Ce que le produit est

Un **compagnon de visualisation** local pour une installation SolarFlow domestique, sur macOS 14+.

### 5.2 Ce que le produit n'est pas

| Hors périmètre | Pourquoi |
|---|---|
| Un serveur / une intégration domotique | HA occupe ce terrain ; l'app est le client léger complémentaire |
| Un système de pilotage automatisé | Écrit sur une vraie batterie → toute automatisation demande une validation explicite (voir v2.4) |
| Une app multiplateforme | Le cœur du produit *est* l'intégration native macOS |
| Un service exposé sur internet | L'API zenSDK n'a **aucune authentification** — le port-forward est explicitement déconseillé dans la doc |
| Un produit multi-comptes / SaaS | Mono-utilisateur, mono-installation, mono-Mac |

---

## 6. Exigences fonctionnelles

Statut : **L** = livré · **P** = planifié · **E** = exploratoire.

### 6.1 Affichage ambiant (barre de menus) — cœur du produit

| ID | Exigence | Statut |
|---|---|---|
| F-01 | Afficher la production solaire live (W) dans la barre de menus, rafraîchie toutes les 5 s (2–60 s configurable) | L |
| F-02 | Choisir ce qui s'affiche : solaire W, batterie %, maison W, ou icône seule | L |
| F-03 | État « pas de données » explicite (`— W`) quand non configuré | L |
| F-04 | Icône ⚠️ « hors ligne » quand l'appareil est injoignable | L |
| F-05 | Conserver la dernière valeur 60 s en cas d'échec de poll (grisée + âge), plutôt que de clignoter | L |

### 6.2 Panneau déroulant

| ID | Exigence | Statut |
|---|---|---|
| F-10 | Cartes : production, batterie (SOC + par pack : SOC/température/tension), flux, consommation maison, historique, économies | L |
| F-11 | Sélecteur de période 15 min / jour / 14 jours, avec pic et comparaison à hier | L |
| F-12 | Répartition solaire du jour : direct vers la maison vs stocké (charge secteur déduite) + total réseau | L |
| F-13 | Cartes repliables au clic (résumé en une ligne) et activables/désactivables individuellement | L |
| F-14 | Pied de connexion indiquant la source réelle : local / repli local / cloud / bascule auto | L |
| F-15 | Cartes réordonnables par glisser-déposer | P (v2.3) |

### 6.3 Tableau de bord

| ID | Exigence | Statut |
|---|---|---|
| F-20 | Fenêtre dédiée avec tous les indicateurs exposés par l'API | L |
| F-21 | **Schéma nodal** : SolarFlow au centre, panneaux / batteries / réseau / maison / prise hors-réseau en périphérie ; les liens s'animent uniquement quand l'énergie circule, watts en pastille | L |
| F-22 | **Lecture Sankey** : largeur de ruban ∝ watts, sources à gauche, usages à droite ; reliquat du hub explicite ; soutirage non mesuré hachuré hors échelle | L |
| F-23 | Bascule schéma ⇄ Sankey persistée entre les sessions | L |
| F-24 | Valeurs strictement identiques dans les deux lectures (source unique : `EnergyMath`) | L |
| F-25 | Champs d'état / de défaut zenSDK (`faultLevel`, `gridState`…) affichés dans la carte Appareil | P (v2.3) |

### 6.4 SunRoad (scène 3D)

| ID | Exigence | Statut |
|---|---|---|
| F-30 | Scène SceneKit native : quartier OpenStreetMap (bâtiments extrudés + routes), maison auto-détectée (< 25 m) ou désignée au clic | L |
| F-31 | Soleil = lumière directionnelle réelle projetant de vraies ombres portées, suivant la course du jour | L |
| F-32 | Champs de panneaux à leur azimut/inclinaison réels, réglables en direct par curseurs | L |
| F-33 | Billes de flux animées cadencées par les watts réels ; ruban de production le long de l'arc solaire | L |
| F-34 | Courbe de consommation maison continue sur le cercle 24 h (piquets 15 min, badge « ⌂ n W ») | L |
| F-35 | Courbe de production attendue en ciel clair, au sol, sur la même base et la même échelle que les barres réelles | L |
| F-36 | Timeline ±48 h, couverture nuageuse voilant la lumière, couches cochables, mode mur | L |
| F-37 | Barre latérale : éphémérides, crépuscules, productible théorique, météo, histogramme 14 jours | L |
| F-38 | Polissage : noms de rues, végétation/plans d'eau, rayon du quartier réglable, lettres cardinales en miroir | P (v2.3) |

### 6.5 Sources de données

| ID | Exigence | Statut |
|---|---|---|
| F-40 | **Local (défaut)** : `GET /properties/report`, parser tolérant (imbriqué ou plat, Int/Double/String) | L |
| F-41 | Découverte Bonjour sur `_zendure._tcp` **et** `_http._tcp` (quirk firmware : instances `Zendure-<produit>-<sn>`) | L |
| F-42 | **Cloud (opt-in)** : Cloud Key → `deviceList` signé SHA1 → MQTT temps réel, client MQTT 3.1.1 maison, **lecture seule** | L |
| F-43 | **Smart Meter 3CT** interrogé sur le LAN dans les deux modes → soutirage réseau mesuré + consommation totale | L |
| F-44 | Hôte de secours (VPN) avec repli mémorisé et retest du principal toutes les 2 min | L |
| F-45 | Bascule automatique local ⇄ cloud (opt-in) : 2 échecs → cloud, sonde locale 60 s → retour | L |
| F-46 | Garde-fou : refuser un Smart CT répondant à l'adresse du SolarFlow (erreur explicite, jamais de zéros silencieux) | L |
| F-47 | Mapper `outputPower` du cloud (topic `properties/energy`, ~3 s) sur le flux maison | P (v2.3) |

### 6.6 Historique et énergie

| ID | Exigence | Statut |
|---|---|---|
| F-50 | Historique multi-jours : barres kWh 7/30/90/365 j par appareil, métriques par source, totaux vie entière | L |
| F-51 | Cache disque des jours passés (immuables, récupérés une seule fois) | L |
| F-52 | Masquer les appareils sans historique réel (payload complet mais entièrement à zéro ⇒ « pas d'historique ») | L |
| F-53 | Export CSV | L |
| F-54 | Collecteur 24/7 optionnel (LaunchAgent + SQLite + API JSON) sur un Mac toujours allumé | L |
| F-55 | Historique du soutirage réseau depuis le Smart CT | P (v2.3) |

### 6.7 Alertes et notifications (toutes opt-in)

| ID | Exigence | Statut |
|---|---|---|
| F-60 | Batterie basse (seuil 5–50 % configurable) | L |
| F-61 | Appareil injoignable au-delà de N minutes (défaut ON, 10 min) | L |
| F-62 | Production nulle en plein jour (défaut ON, 30 min, élévation solaire > 20°) | L |
| F-63 | Batterie pleine, soutirage réseau inattendu, record de production | L |

### 6.8 Widgets et intégration système

| ID | Exigence | Statut |
|---|---|---|
| F-70 | Widgets petit / moyen (état live) et grand (histogramme 14 jours) via App Group | L |
| F-71 | Lancement à l'ouverture de session (`SMAppService`) | L |
| F-72 | Vérification des autorisations en amont (réseau local, localisation, notifications) | L |
| F-73 | Bouton de rafraîchissement du widget (AppIntents) | P (v2.3) |

### 6.9 Contrôle (local uniquement, lecture-écriture)

| ID | Exigence | Statut |
|---|---|---|
| F-80 | Onglet Contrôle : mode AC, limites de sortie/charge via `POST /properties/write` | L |
| F-81 | Indisponible en mode Cloud (cohérence avec P2) | L |
| F-82 | Optimiseur heures creuses / heures pleines (planificateur local) | P (v2.4) |

### 6.10 Réglages et localisation

| ID | Exigence | Statut |
|---|---|---|
| F-90 | Réglages en onglets : appareil, affichage, soleil, notifications, contrôle, réseau, général | L |
| F-91 | Interface localisée français / anglais | L |
| F-92 | Thème auto / sombre / clair | L |
| F-93 | Estimations d'économies (€/kWh et g CO₂/kWh configurables) | L |
| F-94 | Localisation chinoise | P (v2.3) |

---

## 7. Exigences non fonctionnelles

### 7.1 Performance

- **Polling, pas push** : l'appareil n'expose aucun canal push local. Un `GET` de ~2 Ko toutes les 5 s est négligeable des deux côtés. La boucle est un `Task` annulable, redémarré quand l'hôte ou l'intervalle change ; débounce de 800 ms sur les changements de réglages.
- Timeout de 5 s par requête ; en repli VPN, pas de timeout de 5 s sur le principal à chaque poll (repli mémorisé).
- SunRoad doit rester fluide au glissement des curseurs d'orientation — **validé en réel sur un build Debug** (le cas pessimiste).

### 7.2 Sécurité et vie privée

- **Aucune donnée ne quitte le Mac** dans le chemin par défaut. Les éphémérides sont calculées localement (algorithme NOAA), pas récupérées d'un service.
- Sorties réseau externes, toutes optionnelles et déclarées : Open-Meteo (météo), Overpass/OSM (quartier, mis en cache disque), serveurs Zendure (mode Cloud, Historique).
- **Secrets au trousseau macOS uniquement** : Cloud Key, identifiants du compte de l'app mobile (stockés séparément). Les jetons bruts ne sont jamais écrits sur disque en clair.
- Mode Cloud **lecture seule par construction**.
- **Ne jamais exposer le port 80 de l'appareil sur internet** — l'API zenSDK n'a aucune authentification. Le VPN (Tailscale/WireGuard avec routage de sous-réseau) est le seul schéma d'accès distant documenté.
- `NSLocalNetworkUsageDescription` + `NSBonjourServices` ; `NSAllowsLocalNetworking` pour le HTTP en clair vers les hôtes `.local`.

### 7.3 Fiabilité

- **Politique de donnée périmée** : sur erreur, la dernière lecture reste visible avec un avertissement pendant 60 s, puis bascule en « pas de données ». Évite le clignotement sur un poll manqué isolé.
- Bascule de jour à **minuit local** (pas UTC).
- Reprise après veille : replanification commune des reconnexions MQTT et HTTP, timeout PINGRESP (socket à moitié mort), observation de `NSWorkspace.didWakeNotification`.
- Diagnostic MQTT explicite : codes SUBACK interprétés, détection de reprise de session (« une seule session temps réel par Cloud Key »), entrées de `deviceList` malformées filtrées.

### 7.4 Qualité et distribution

| Exigence | Niveau actuel |
|---|---|
| Tests unitaires sur toute logique pure (parsers, éphémérides, géométrie solaire, calculs d'énergie, watchdog, projection géo) | 113 tests verts |
| CI sur chaque PR | GitHub Actions |
| Cible système | macOS 14+ |
| Signature | Developer ID (`KFLACS69T9`), Hardened Runtime, horodatage sécurisé |
| Notarisation | `notarytool` + agrafage, vérification indépendante (`spctl`, `stapler validate`) après chaque release |
| Mise à jour | Sparkle 2.9.1, appcast servi depuis `main`, DMG signé EdDSA |
| Documentation | README technique complet, guide utilisateur FR+EN (12 pages), wiki, landing page |

**Contraintes de release non négociables** (apprises à la dure) :
1. La release GitHub est créée **avant** le push de l'appcast — l'ordre inverse expose les clients Sparkle à un 404.
2. La clé EdDSA Sparkle n'est **jamais** régénérée (casserait l'auto-update de tous les utilisateurs installés).
3. `Info.plist` est généré par XcodeGen depuis `project.yml` — ne jamais l'éditer directement.
4. Ne jamais laisser tourner un build Debug signé ad hoc comme app du quotidien : macOS invalide silencieusement l'autorisation réseau local à chaque rebuild.

---

## 8. Architecture

Swift / SwiftUI pur, projet généré par XcodeGen depuis `project.yml`. Application agent (`LSUIElement`) avec `MenuBarExtra` en style `.window`. 46 fichiers sources.

```
Sources/
  ZendureMonitorApp.swift   @main — MenuBarExtra, scènes Réglages / Dashboard / SunRoad / Historique
  Monitor.swift             @MainActor — boucle de poll, bascule de source, persistance, notifications
  DeviceState.swift         modèle zenSDK + parser tolérant (+ garde-fou de signature)
  SmartCT.swift             rapport local du SmartMeter3CT (par phase + total)
  Discovery.swift           navigateur Bonjour (_zendure._tcp + _http._tcp)
  Cloud/                    Cloud Key, deviceList signé, MQTT 3.1.1 maison, trousseau, API app mobile,
                            service d'historique — lecture seule par conception
  SunRoad/                  scène SceneKit, Overpass/OSM, projection géo, barre latérale
  Components/               cartes, jauges, sparklines, schéma de flux, Sankey — langage visuel partagé
                            avec MacInside
  Shared/                   Format, SunCalc (NOAA), SolarGeometry, EnergyMath, DailyAccumulator,
                            OutageWatchdog, WidgetSnapshot — logique pure, compilée dans les tests
Tests/                      13 suites, 113 tests
```

**Choix structurants :**
- L'étiquette de la barre de menus est un `Text` avec un symbole SF interpolé — c'est ce qui permet d'afficher une valeur vivante.
- Toute logique calculatoire vit dans `Shared/`, sans dépendance à l'UI ni au réseau : c'est la surface testable.
- `EnergyMath` est la **source unique** des grandeurs dérivées (`gridToHome`, `homeTotal`, répartition du solaire) — panneau, schéma et Sankey y puisent, ce qui interdit structurellement une divergence entre les vues.
- Convention d'azimut fixée partout : **0° = nord, 90° = est, 180° = sud, 270° = ouest**. Beaucoup d'outils solaires prennent sud = 0 — une conversion silencieuse fausserait l'incidence sans rien casser visiblement.

---

## 9. Sources de données

| Source | Protocole | Rôle | Optionnelle |
|---|---|---|---|
| SolarFlow (LAN) | HTTP `GET /properties/report`, port 80 | Chemin par défaut : tout l'état en un JSON | Non — c'est le produit |
| SolarFlow (LAN) | HTTP `POST /properties/write` | Onglet Contrôle, local uniquement | Oui |
| SmartMeter 3CT (LAN) | HTTP `GET /properties/report` | Soutirage réseau réel → arc mesuré, conso totale maison | Oui |
| Cloud Zendure | `deviceList` signé SHA1 → MQTT `mqtteu.zen-iot.com:1883` | Repli quand le LAN est injoignable | Oui, opt-in |
| API privée de l'app mobile | HTTP (Blade-Auth, endpoints tdengine) | Historique long terme (jusqu'à 365 j) | Oui, opt-in |
| Open-Meteo | HTTPS | Couverture nuageuse, prévision ajustée (Kasten–Czeplak) | Oui |
| Overpass / OpenStreetMap | HTTPS | Bâtiments et routes du quartier (cache disque) | Oui |
| Collecteur 24/7 | HTTP JSON local | Historique indépendant de l'allumage du Mac | Oui |

**Modèle de productible** (`SolarGeometry`) : 85 % direct × cos(incidence) × transmittance de Meinel (0,7^(masse d'air^0,678), normalisée à 1 au zénith) + 15 % diffus × sin(élévation) × (1+cos inclinaison)/2, le tout × 0,9 de pertes. La transmittance est indispensable : sans elle, une façade ouest annonçait 323 W au coucher au lieu de 30 W. Validé sur données réelles : réel ≤ prévu + 4 % au maximum.

---

## 10. Parcours utilisateur clés

**PU-1 — Première installation (objectif : < 2 minutes).** Télécharger le DMG → glisser dans /Applications → lancer → accepter l'autorisation réseau local → Réglages → « Rechercher sur le réseau » → tester la connexion. *Point de friction connu :* si la découverte ne trouve rien, l'API locale peut être désactivée sur l'unité — le contournement documenté est d'ajouter une intégration HEMS dans l'app mobile puis de la quitter.

**PU-2 — Coup d'œil quotidien (objectif : zéro clic).** La valeur est déjà dans la barre de menus.

**PU-3 — « Où va mon énergie ? »** Clic sur l'icône → carte Flux ; pour le détail, ouverture du tableau de bord → schéma ou Sankey selon qu'on cherche la topologie ou la répartition.

**PU-4 — Optimiser l'orientation des panneaux.** SunRoad → curseurs azimut/inclinaison → la scène 3D, l'incidence et le productible suivent le geste ; l'écart entre courbe attendue et barres réelles se lit sur la même échelle.

**PU-5 — Consulter depuis l'extérieur.** Soit VPN (Tailscale, routage de sous-réseau) + hôte de secours, soit bascule automatique vers le Cloud. Limite assumée : le Smart CT étant LAN-only, la consommation maison est marquée « partielle » à distance.

---

## 11. Métriques de succès

Produit personnel devenu public — les métriques sont qualitatives et opérationnelles plus que commerciales.

| Métrique | Cible |
|---|---|
| Temps du lancement à la première valeur affichée | < 2 min |
| Disponibilité de l'affichage (valeur fraîche présente quand le LAN est sain) | > 99 % du temps d'allumage du Mac |
| Valeur inventée ou zéro silencieux affiché à l'utilisateur | **0 occurrence** (P3) |
| Tests verts sur `main` | 100 %, à chaque PR |
| Releases notarisées et vérifiées indépendamment | 100 % |
| Régressions signalées par des utilisateurs externes | à traiter en patch sous 48 h (précédent : v1.11.1) |
| Couverture doc : chaque fonctionnalité visible documentée dans le guide FR **et** EN | 100 % |

---

## 12. Roadmap

### Livré (v1.0 → v2.2)

| Version | Apport majeur |
|---|---|
| 1.0–1.2 | Production live en barre de menus, découverte Bonjour, Sparkle, graphes, options d'affichage, historique multi-jours |
| 1.3–1.4 | Widget macOS, onglet Contrôle, export CSV, tableau de bord, collecteur 24/7 |
| 1.5–1.6 | Schéma de flux centré sur le hub, fenêtre Soleil, économies, notifications, tests + CI, répartition solaire, résilience hors ligne |
| 1.7–1.9 | Grand widget, météo, alertes de panne, fenêtre Soleil v3 (dôme céleste, compas, orientations réglables) |
| 1.10–1.12 | Mode Cloud, Smart CT, carte Consommation maison, bascule auto, cartes repliables, fenêtre Historique |
| 2.0–2.2 | **SunRoad** (quartier 3D, vraies ombres), courbes conso/prévision, **lecture Sankey** du flux |

### v2.3 — Consolidation *(prochaine)*

Polissage SunRoad (noms de rues, végétation, rayon réglable, lettres cardinales en miroir), mapping de `outputPower` en mode Cloud, champs de défaut zenSDK au tableau de bord, localisation chinoise, cartes réordonnables, bouton de rafraîchissement du widget, historique du soutirage depuis le Smart CT.

### v2.4 — Optimiseur heures creuses / heures pleines

Planificateur local pilotant la batterie via `POST /properties/write` selon les plages tarifaires. **Rupture de principe** : c'est la première fonctionnalité qui écrit de façon autonome sur du matériel réel. Elle exige un plan dédié, validé avant toute ligne de code, et probablement un garde-fou de type « proposition à confirmer » plutôt qu'une automatisation muette.

### Exploratoire (non engagé)

Support multi-appareils de premier ordre (un utilisateur à deux SolarFlow existe déjà) ; export vers Home Assistant ou Prometheus ; app iOS compagnon (contredirait le positionnement macOS-natif — à trancher, pas à supposer).

---

## 13. Risques et dépendances

| Risque | Impact | Atténuation |
|---|---|---|
| **API zenSDK non contractuelle** — Zendure peut la modifier ou la désactiver par firmware | Critique : c'est le chemin par défaut | Parser volontairement tolérant ; le mode Cloud est déjà le repli ; suivi du dépôt zenSDK |
| **API privée de l'app mobile** (Historique) — non documentée, non stable | L'Historique casse | Fonctionnalité isolée et optionnelle ; échec dégradé, jamais bloquant |
| **Quirks de firmware** (Bonjour en `_http._tcp`, API locale désactivée par défaut) | Découverte en échec au premier lancement | Les deux types de service sont explorés ; contournement HEMS documenté dans le README et le guide |
| **TCC réseau local invalidé** au remplacement de l'app | Poll en échec silencieux, très difficile à diagnostiquer | `lsregister -f` après installation ; bandeau de détection dans l'app ; interdiction de faire tourner un build Debug au quotidien |
| **Reprise de session MQTT** — une seule session temps réel par Cloud Key | Boucle de reconnexion en mode Cloud si HA/ioBroker utilise la même clé | Détectée et expliquée à l'utilisateur (v1.11.1) |
| **Throttling Overpass** | Quartier SunRoad vide | Cache disque par coordonnées, repli sur le cache voisin |
| **Bus factor = 1** | Continuité du projet | Code MIT et public ; décisions et pièges consignés dans `MEMORY.md` |
| **Base matérielle de test = une seule unité** (SolarFlow 2400 Pro) | Régressions invisibles sur les autres modèles | Parser tolérant ; retours utilisateurs traités en patch rapide |

---

## 14. Questions ouvertes

1. ~~**Multi-appareils**~~ — **tranché le 2026-10-03** (Vincent a lui-même ajouté un 2ᵉ SolarFlow) : l'agrégation devient de premier ordre — une installation additionnée partout, une carte « Appareils » pour le détail, totaux signalés partiels quand un appareil manque, commandes toujours ciblées sur un appareil précis.
2. **v2.4 et l'écriture autonome** — jusqu'où l'optimiseur peut-il aller sans confirmation ? Le principe P2 (lecture seule par défaut) demande un arbitrage explicite avant tout développement.
3. **Le collecteur 24/7 est-il durable ?** Il demande un Mac toujours allumé et a déjà coûté des incidents (TCC, veille de [Mac-collecteur]). L'Historique par l'API mobile le recouvre partiellement — faut-il le déprécier ?
4. **Portée de la localisation** — le chinois est planifié en v2.3 ; sur quel signal de demande réelle ?

---

## Annexes

- **Références externes :** [Zendure/zenSDK](https://github.com/Zendure/zenSDK) (`docs/en_properties.md`) · [Gielz1986/Zendure-HA-zenSDK](https://github.com/Gielz1986/Zendure-HA-zenSDK) · [Sparkle](https://sparkle-project.org) · [Open-Meteo](https://open-meteo.com) · [Overpass API](https://overpass-api.de)
- **Documents du projet :** `README.md` (technique, public) · `PLAN.md` (découpage d'exécution) · `TODOS.md` (avancement) · `MEMORY.md` (état, décisions, pièges) · `CHANGES.md` (journal) · `docs/guide/` (guide utilisateur FR/EN)
- **Matériel de référence :** SolarFlow 2400 Pro + SmartMeter 3CT. Modèles compatibles attendus : SolarFlow 2400 AC / AC+ / AC Pro, 800 (Pro/Plus), 1600 AC+, 3000 Mix AC+, 4000 Mix.
