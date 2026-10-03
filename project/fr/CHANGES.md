# CHANGES — Zendure Monitor

## 2026-10-03 (contrôle : réserve, charge max, injection — mergé sur main `0607492`, non poussé)

### Added
- Onglet Contrôle, section **« Réserve, charge et injection »** : réserve (`minSoc`, 0-50 %), charge maximale (`socSet`, 70-100 %), **injection du surplus** (`gridReverse` 1 autorisée / 2 interdite — confirmation rappelant la convention CACSI Enedis), valeurs actuelles de chaque appareil visé. Cible **« Tous les appareils »** (envoi séquentiel, arrêt et message au premier échec). Mention de la régulation Zendure qui écrase `outputLimit` et du smartMode (écritures non permanentes).
- `DeviceState.gridReverse` / `feedInAllowed` (parser local + cloud, nil sur l'agrégat), ligne « Injection du surplus » dans la carte Appareils détaillée. 26 traductions anglaises.

### Decisions
- Échelle d'écriture : dixièmes de % (`minSoc` 20 % → 200), comme l'intégration officielle Zendure-HA (`number.py` : `int(self.factor * value)`, factor 10) — la doc zenSDK dit « % » mais le firmware renvoie 1000/100.
- Valeurs de `gridReverse` : 0 désactivée, 1 autorisée, 2 interdite (`entity.py` de Zendure-HA) ; seule 1 permet l'export. Les deux SolarFlow de Vincent étaient à 2 → production bridée batterie pleine.
- Aucune écriture faite sur les appareils par Claude : Vincent applique depuis l'onglet.

## 2026-10-03 (CI rouge depuis la v2.2.0)

### Fixed
- **CI GitHub en échec depuis le 13/08** (merge du Sankey, 6 runs rouges dont #62) : `SankeyFlowView.swift:176` — `cannot assign value of type '(CGFloat, Double, CGFloat)'`. Le runner `macos-latest` compile avec Xcode 26.6, qui ne convertit pas implicitement le `scale` Double en CGFloat ; Xcode 27.2 / Swift 6.4 en local si — d'où un build local et des releases intacts. Correction à la source : `scale` calculé en CGFloat (`/ CGFloat(columnTotal)`), aucun changement numérique. Branche `fix/ci-sankey-cgfloat`, **PR #18 verte** (build + 124 tests sur Xcode 26.6), mergée (`a8fe539`) — CI de `main` de nouveau verte.

### Decisions
- Avant de merger une vue graphique, ne pas se fier au seul Xcode local (beta 27.x) : la CI est le seul compilateur Xcode 26 disponible — regarder son statut après chaque push.

## 2026-10-03 (release v2.3.0)

### Added
- **Release v2.3.0 (build 23)** — multi-appareils. Après acceptation du contrat Apple Developer par Vincent : DMG 4,2 Mo **notarisé Accepted** + agrafé + validé + signé Sparkle, release GitHub `v2.3.0` créée **avant** le push de l'appcast (`1cf1044`), asset HTTP 200, appcast servi en version 23. Installée **depuis le DMG** : `spctl` source=Notarized Developer ID, `codesign --deep --strict` OK, `stapler validate` OK ; total vérifié en réel 973 W = 491 + 483 W, SOC 71 % = (44+98)/2.

### Decisions
- Pour tester l'accès à la notarisation, utiliser un vrai `notarytool submit` (zip d'une app signée, `--no-wait`) : `notarytool history` réussit même sans contrat en vigueur et a donné un faux feu vert.

## 2026-10-03 (préparation v2.3.0 — bloquée à la notarisation)

### Docs
- Branche `release/2.3.0` : bump 2.3.0 / build 23, README « New in 2.3 » + roadmap (v2.3 multi-appareils cochée, SunRoad → v2.4, optimiseur → v2.5), carte landing « Several SolarFlow, one installation », `release/release-notes-2.3.0.md`. 124 tests verts.

### Blocked
- `xcrun notarytool` → **HTTP 403 « A required agreement is missing or has expired »** (deux essais). Contrat Apple Developer à accepter par Vincent ; `release.sh` non lancé. `main` poussé (`1030941`) sans l'appcast : aucun utilisateur n'est affecté.

## 2026-10-03 (multi-appareils : deux SolarFlow agrégés — branche feat/multi-device)

### Fixed
- **L'app ne voyait qu'un des deux SolarFlow** de Vincent (2ᵉ appareil ajouté : SN [SN-2] en [IP], à côté de [SN-1] en [IP]). Cause racine : architecture **mono-appareil par conception** — un seul `deviceHost` interrogé en local, un seul `cloudDeviceKey` suivi en cloud, un seul `DeviceState` consommé partout. Pas un défaut de découverte : les deux s'annoncent en Bonjour et répondent à `/properties/report`.

### Added
- `DeviceState.combine` (pur, 7 tests) : puissances additionnées, packs concaténés, SOC pondéré par nombre de packs (aucun champ capacité dans `packData` ; chaque appareil a un pack type 500 + un 350), valeurs propres à un appareil (SN, voies PV, limites, mode AC, socMin/Max, temp., rssi, BatVolt, autonomie) → nil. Invariant testé : un seul appareil ⇒ état strictement identique.
- `DeviceReading` + `Monitor.devices` : lecture par appareil (hôte qui a répondu, état ou erreur). Carte **« Appareils »** (`Components/DevicesCard.swift`) dans le panneau (compacte : solaire, SOC + flux batterie, injection, hôte) et dans le tableau de bord (détaillée : + voies PV, température, Wi-Fi, mode AC, limites, plage de charge) — remplace la carte « Appareil » quand il y en a plusieurs.
- **Totaux partiels signalés** (`partialMessage`) quand un appareil manque : bandeau orange panneau + tableau de bord, la somme n'est jamais présentée comme complète.
- Watchdog **par appareil** : anomalie de production nulle en plein jour par SolarFlow (sinon noyée dans la somme), notification « Un SolarFlow ne répond plus » quand les autres répondent. La coupure totale garde l'alerte historique.
- Traductions anglaises des 20 nouvelles chaînes dans `Localizable.xcstrings` (format compact du catalogue préservé).

### Changed
- Réglages → Appareil : **liste d'adresses** (ajout/retrait, test de tous les hôtes), « Rechercher sur le réseau » propose « Ajouter » par appareil trouvé et écarte le Smart CT (qui s'annonce aussi en `Zendure-…`).
- Poll local **en parallèle** (TaskGroup) — un appareil éteint n'ajoute pas son timeout de 5 s au cycle. `fallbackHost` rattaché au premier appareil. Bascule auto Cloud seulement si **tous** échouent ; sonde de retour sur n'importe quel hôte.
- Mode Cloud : tous les appareils du deviceList agrégés (le sélecteur « Appareil suivi » et `cloudDeviceKey` disparaissent ; périmé/absent → lecture en erreur → totaux partiels).
- **Contrôle** : cible un appareil précis (SN + hôte qui a répondu) via un sélecteur quand il y en a plusieurs — jamais l'agrégat, dont le SN est nil pour qu'aucun chemin oublié ne puisse piloter une batterie à l'aveugle.
- Réglage `deviceHost` → `deviceHosts` (tableau), **migration matérialisée** à l'ouverture ; `deviceHost` reste écrit avec le premier hôte (retour arrière possible vers une version antérieure).

### Changed (suite, même jour)
- **Alertes batterie faible / pleine par appareil** (choix de Vincent) : logique pure `Shared/BatteryAlerts.swift` (hystérésis 5 points, un envoi par épisode, plafond `socMax` propre à l'appareil, 4 tests dont « un vide + un plein = alerte malgré la moyenne de 55 % »). Avec un seul appareil, titres et identifiants de notification inchangés ; à plusieurs : « Batterie faible — SolarFlow 2 », id suffixé par appareil.
- Mergé `--no-ff` sur `main` (non poussé).

### Verified
- 124 tests verts (113 + 7 agrégat + 4 alertes). `xcodebuild` OK.
- Build Release signé Developer ID installé dans `/Applications` à la place de la 2.2.0 notarisée (retour arrière : DMG 2.2.0 dans `release/`) : migration observée (`deviceHosts = [.46]`), puis deux hôtes → instantané widget 641 W pour 494 + 146 W mesurés directement, SOC 72 % = (46 + 98)/2 ; second relevé 499 W / 73 % pour 501 + 0 W, SOC 46 et 100.
- Rendu PNG hors écran **regardé** (harnais `swiftc` jetable, thèmes sombre et clair) : carte compacte, carte détaillée, appareil injoignable, schéma de flux et Sankey à 4 packs. Un défaut corrigé avant clôture : SN tronqué + IP illisible dans la carte compacte → l'hôte seul.
- **Mode Cloud vérifié en réel** via l'app elle-même (bascule auto coupée le temps du test, réglages restaurés ensuite) : SOC agrégé 73,5 % = (47 + 100)/2 → les deux appareils sont dans le deviceList et agrégés. Une première sonde CLI du deviceList a été abandonnée : `security find-generic-password` ouvrait une demande d'accès au Trousseau chez Vincent.
- **Non vérifié** : l'onglet Réglages (pas de rendu possible sans `Monitor`).
- **Collecteur 24/7 (`[collector-host].local:8899`) mono-hôte** (`ZENDURE_HOST=.46`) et **à l'arrêt de fait** (`/health` → `lastSample: null`, `/today` → 0 Wh). L'app retient le max entre son cumul et celui du collecteur : tant qu'elle tourne, c'est la somme des deux appareils qui l'emporte. Collecteur non modifié (déployé sur [Mac-collecteur]).

## 2026-08-14 (PRD)

### Docs
- **`PRD.md` créé** à la racine (français, gitignoré avec les autres docs de session) — PRD rétroactif et prospectif : formalise le produit tel qu'il est livré en 2.2.0 et cadre v2.3/v2.4. 14 sections : résumé exécutif, contexte/problème, 5 principes directeurs, personas et non-cibles, périmètre, 56 exigences fonctionnelles numérotées (F-01…F-94, 10 domaines, statut livré/planifié/exploratoire), exigences non fonctionnelles, architecture, sources de données, parcours utilisateur, métriques, roadmap, risques, questions ouvertes.
- Les principes directeurs ne sont pas inventés a posteriori : ils sont extraits des arbitrages réellement tracés dans `MEMORY.md` (local d'abord, lecture seule par défaut, honnêteté des données, zéro dépendance superflue, « une vue qui compile n'est pas une vue qui marche »). Le PRD explicite que la bande hachurée hors échelle du Sankey et l'arc « non mesuré » du schéma sont deux conséquences du même principe.
- Quatre questions ouvertes consignées pour arbitrage : multi-appareils, marge d'écriture autonome de l'optimiseur v2.4 (rupture avec le principe de lecture seule), avenir du collecteur 24/7 face à l'Historique par l'API mobile, signal justifiant la localisation chinoise.

### Changed
- `.gitignore` : ajout de `PRD.md` à la section « Claude session docs ». **Seule modification suivie de la session, non commitée** (pas demandé).

### Decisions
- Le PRD est **en français et gitignoré**, par cohérence avec `PLAN.md`/`MEMORY.md` : c'est un document de travail interne, et il cite des détails d'infrastructure personnelle. À rebasculer en anglais et versionné si le PRD doit devenir public.
- Répartition des rôles documentaires arrêtée : **PRD** = quoi et pourquoi (périmètre, principes, exigences, risques) · **PLAN** = découpage d'exécution · **TODOS** = avancement · **MEMORY** = état vécu, décisions et pièges · **README/guide** = documentation publique.

## 2026-08-13 (release v2.2.0)

### Added
- **Release v2.2.0 (build 22)** : la lecture Sankey du flux d'énergie. Bump via `release/2.2.0` (`53d0c76`), DMG 4,1 Mo **notarisé Accepted** + agrafé + validé + signé Sparkle, release GitHub `v2.2.0` créée **avant** le push de l'appcast (`76f45a8`), asset vérifié HTTP 200. Installée **depuis le DMG** puis relancée : `spctl` accepted **source=Notarized Developer ID**, `codesign --verify --deep --strict` OK, `stapler validate` OK, version 2.2.0 build 22 confirmée, snapshot widget frais (11 s). 113 tests verts avant release.

### Docs
- **Landing page** (`docs/index.html`) : carte « Energy-flow dashboard » réécrite en « Energy flow — two readings », section dashboard complétée, **seconde figure** avec la capture Sankey et une légende qui explique ce que le schéma ne peut pas montrer.
- **README** : paragraphe « New in 2.2 », roadmap — v2.2 cochée sur le Sankey, l'ancien backlog v2.2 glissé en v2.3, l'optimiseur en v2.4.
- `release/release-notes-2.2.0.md`.

## 2026-08-13 (app relancée avec le Sankey)

### Changed
- **Build Release local signé Developer ID installé dans `/Applications`** à la place de la 2.1.0 notarisée, app relancée (PID 57593). Procédure de `Scripts/release.sh` sans DMG ni notarisation : staging `ditto --noextattr`, codesign deepest-first (appex + entitlements → binaires Sparkle → framework → app, Hardened Runtime + timestamp). Vérifications indépendantes : `spctl` accepted / source=Developer ID, `codesign --verify --strict --deep` OK.

### Note
- ⚠️ La version n'a pas bougé (**2.1.0 build 21**) : l'app en place contient le Sankey mais n'est **pas notarisée**, Sparkle ne proposera aucune mise à jour, et une réinstallation depuis le DMG 2.1.0 ferait perdre la vue. **Une release 2.2.0 est nécessaire pour distribuer le Sankey.**

## 2026-08-13 (notes de release versionnées + cause racine dans le script)

### Fixed
- **`release/release-notes-2.1.0.md` n'était pas suivi** — seule version manquante sur les 21, les 20 autres étant versionnées depuis toujours. Commité.
- **Cause racine dans `Scripts/release.sh`** : le rappel de fin de script (« Next steps ») ne demandait de committer que `appcast.xml`, jamais les notes de release — alors qu'elles sont versionnées et que le DMG, lui, est gitignoré. Le rappel inclut désormais `release/release-notes-$VERSION.md`, sinon l'oubli se reproduira à chaque release.

### Note
- Ma lecture initiale de `CLAUDE.md` (« les artefacts de release doivent être gitignorés ») était trop large : la règle vise les binaires (`*.dmg`, `*.zip`), et l'usage réel du dépôt versionne les notes de release. C'est l'usage du dépôt qui fait foi.

## 2026-08-13 (merge Sankey + captures d'écran refaites)

### Changed
- **Merge `--no-ff` de `feat/sankey-energy-flow` sur main** (`8d9dc08`) — non poussé.
- **Captures du tableau de bord refaites sur données réelles** (poll local, 16:48:18, 435 W solaire / 1,19 kW réseau / Maison 1,63 kW, sparklines à 131 points) : `docs/dashboard.png` (schéma, 144 dpi) et `docs/guide/images/dashboard-light.png` (72 dpi) montrent désormais le sélecteur Schéma/Sankey ; deux nouvelles, `docs/dashboard-sankey.png` et `docs/guide/images/dashboard-sankey.png`, montrent la lecture Sankey **au même instant et avec les mêmes chiffres** — la comparaison est donc valide. README et guides fr/en mis à jour pour les référencer.

### Decisions
- **Le rendu des captures passe par `NSHostingView.cacheDisplay`, pas par `ImageRenderer`.** `ImageRenderer` remplace un `Picker` segmenté par un rectangle jaune barré — et c'est précisément le nouveau contrôle à documenter. `cacheDisplay` rend les contrôles AppKit natifs. (Le contenu du tableau de bord fait 1051 pt de haut pour une fenêtre de 720 : une capture d'écran de fenêtre ne peut pas le montrer en entier, d'où le rendu hors fenêtre.)
- **Harnais de capture jetable, hors du dépôt** : les sources de l'app compilées à part (`swiftc`, `Updater` stubbé faute de Sparkle linkable), empaquetées en `.app` sous un bundle id **distinct** (`fr.lauriat.ZendureMonitorShots`) avec une **copie** des préférences — le harnais n'écrit jamais dans le domaine de l'app réelle, l'accumulateur journalier de Vincent n'est pas touché. Les sparklines vivant en mémoire (un point par poll), le harnais préchauffe 5 min à 2 s de poll avant de rendre.

## 2026-08-13 (Tableau de bord : diagramme de Sankey en seconde représentation)

### Added
- **`SankeyFlowView`** — seconde lecture des flux du tableau de bord, à côté du schéma nodal : la largeur du ruban vaut les watts, donc la répartition (solaire → maison vs solaire → batterie) se lit d'un coup d'œil. Trois colonnes (sources / SolarFlow / usages), rubans en cubiques, tirets animés dans le sens réel à vitesse liée à la puissance (même langage qu'`EnergyFlowView`, axe médian tracé en tirets épais puis écrêté par le ruban). SOC + SOC par pack portés par le nœud Batteries, température par le libellé du hub : la vue Sankey ne perd aucune information du schéma.
- **Sélecteur segmenté « Schéma / Sankey »** dans la carte Flux d'énergie, choix persisté (`@AppStorage("energyFlowStyle")`, enum `FlowStyle`). Placé dans le contenu de la carte, pas dans `MetricCard` (composant partagé avec MacInside — rayon d'impact nul).

### Decisions
- **Le déséquilibre du hub est matérialisé, pas absorbé.** Un Sankey affirme visuellement la conservation ; le SolarFlow ne boucle jamais exactement (pertes de conversion, bruit de mesure). Ruban gris explicite, symétrique dans les deux sens : « Pertes & conversion » si entrées > sorties, « Écart de mesure » sinon. Les deux colonnes ont ainsi la même hauteur par construction.
- **Le soutirage direct non mesuré garde une épaisseur FIXE et hachurée**, hors échelle, et coiffe de la même façon la barre du nœud Maison. Lui donner une largeur proportionnelle inventerait une valeur, l'omettre affirmerait qu'il vaut zéro — c'est le point où un Sankey ment le plus facilement, puisqu'il prétend tout montrer.
- **Colonnes alignées par le haut, soutirage direct au créneau supérieur des deux colonnes** : il circule alors dans la bande libre au-dessus de la barre du hub et **ne croise aucun autre ruban**, sans heuristique d'ordonnancement.
- **Aucune épaisseur plancher sur les rubans** : un minimum par flux désaccorderait la somme des rubans de la hauteur de la barre du nœud. Les flux ≤ 1 W (même seuil qu'`EnergyFlowView`) sont écartés, le reste est strictement proportionnel.
- **Valeurs identiques aux deux vues** — `EnergyMath.gridToHome` / `homeTotal`, `batteryFlow` signé, `flowText` (▲/▼) et `Format.watts` repris tels quels : basculer d'une représentation à l'autre ne change jamais un libellé.


### Fixed (après vérification visuelle — trois défauts que la relecture du code n'avait pas donnés)
- **Les tirets couvraient toute l'épaisseur du ruban.** Un trait aussi large que la bande produit des dalles perpendiculaires au tracé, qui se pincent dans les courbes : sur le ruban solaire de 240 pt, le rendu était un code-barres, pas un flux. Les tirets courent désormais sur des **voies parallèles** à l'intérieur du ruban (une voie tous les ~16 pt, 6 au plus, épaisseur bornée à 6 pt).
- **Libellés qui se chevauchaient et sortaient de la vue.** Deux nœuds fins voisins en bas de colonne (prise hors-réseau + ruban de bilan) empilaient leurs textes. Passe de **dépliage** descendante puis remontante par colonne, comme des libellés d'axe ; colonnes de texte élargies (0,24 / 0,76 au lieu de 0,19 / 0,81) — « + réseau : non mesuré » et « consommation totale » étaient tronqués à droite.
- **Le libellé du hub tombait sur le ruban le plus bas** : il est posé dans la marge basse réservée, sous le pied des colonnes.

### Fixed
- Garde-fou zéro flux : l'échelle diviserait par zéro toutes les nuits (NaN dans les `Path`) — `makeLayout` renvoie `nil` sous 1 W et la vue affiche un état « Aucun flux mesurable » avec le SOC. Compte aussi pour le rendu `ImageRenderer` de `DashboardContent`.

### Docs
- README (section Dashboard : les deux lectures), guide `fr/tableau-de-bord.md` + `en/dashboard.md` (sections Schéma / Sankey, avec les deux points de lecture : bilan du hub, flux non mesuré).
- `Localizable.xcstrings` : 9 clés anglaises ajoutées (Représentation, Schéma, Sankey, Aucun flux mesurable, Écart de mesure, Pertes & conversion, entrées/sorties, soutirage direct) — l'extraction automatique n'avait rien produit, l'UI anglaise serait restée en français sur toute la vue.

Build vert, 113 tests verts. **Vérifié à l'écran**, pas seulement au crayon : les cinq états (production sans CT / avec CT à 1,40 kW / décharge de nuit avec et sans CT / repos) rendus en PNG via `ImageRenderer` dans un harnais jetable hors projet, et regardés. Confirmé : colonnes de hauteur égale, soutirage direct qui passe au-dessus du hub **sans croiser aucun ruban**, hub dimensionné sur ce qui le traverse vraiment (la nuit : 460 W dans le hub pendant que 1,25 kW le contourne), Maison 2,33 kW = 1400 + 934. Branche `feat/sankey-energy-flow` — **validation par Vincent dans l'app en attente** (le rendu hors app n'a pas les matériaux ni le thème).

## 2026-08-11 (release v2.1.0)

### Added
- **Release v2.1.0 (build 21)** : courbes SunRoad (conso 24 h à la Helios + production prévue ciel clair sur échelle commune, badge « ⌂ W »), fix Historique SmartMeter 3CT (zéros ≠ données), garde-fou notASolarFlow sur le poll local. Merge `feat/sunroad-curve-tuning` (`8ab0865`), bump `release/2.1.0` (`ce1d2a4`), DMG 4,0 Mo notarisé (Accepted) + agrafé + signé Sparkle, release GitHub `v2.1.0` créée avant le push de l'appcast (`4b353fd`), asset HTTP 200. Installée depuis le DMG (attention : point de montage avec espace), spctl `Notarized Developer ID`, codesign strict OK, build 21 confirmé, snapshot frais. README : « New in 2.1 », roadmap v2.1 cochée, backlog renuméroté (v2.2 polish, v2.3 optimiseur).

## 2026-08-11 (SunRoad : production posée au sol, prévu/réalisé comparables)

### Changed
- **La production quitte le dessous de l'arc pour le sol** : les bâtons pendaient depuis l'arc (dont la hauteur varie — zéro non horizontal), la prévision n'était pas comparable visuellement. Réel (bâtons turquoise) et prévu (courbe jaune) partagent désormais le **même cercle horaire au sol** (`productionRadius = domeRadius - 8`, la conso reste à `- 14`), la même base et la même échelle (max des deux pics) ; hauteur de pic commune aux trois séries (`curveMaxHeight = 26 m`). Chaque bâton doit toucher la courbe si la journée tient sa promesse. Guide fr/en réécrit. 113 tests verts. Branche `feat/sunroad-curve-tuning` (`c2c7552`), app locale relancée — **non mergée**.

## 2026-08-11 (SunRoad : courbe de conso ×2 + courbe de production prévue)

### Changed
- **Courbe de consommation deux fois plus haute** (26 m au pic au lieu de 13) — retour visuel de Vincent.

### Added
- **Courbe de production prévue** sous l'arc : le productible **ciel clair** (`SolarGeometry.clearSkyWatts`, mêmes hypothèses que la carte Productible de la sidebar) des champs configurés, un point par quart d'heure aux positions réelles du soleil, en jaune translucide. **Échelle commune** avec les bâtons réels (max des deux pics) : l'écart prévu/réalisé se lit directement. La courbe suit la **timeline ±48 h** (elle se trace aussi hors du jour courant, sans le réel) et se recalcule quand les **sliders d'orientation** bougent. Guide fr/en. 113 tests verts. Branche `feat/sunroad-curve-tuning` (`3089a11`), installée en local pour validation visuelle — **non mergée**.

## 2026-08-11 (merge + déploiement local : courbe de conso + garde-fou CT)

### Changed
- **Merge `--no-ff` sur main et push** (`a7b548e..3af52ea`) : `fix/reject-non-solarflow-payload` (`2c95f67`) et `feat/sunroad-consumption-curve` (`3af52ea`), 113 tests verts, branches supprimées. Rebuild Release signé + réinstallation /Applications + relance : snapshot frais (925 W solaire / 699 W maison / SOC 18 %), courbe de conso du jour alimentée. Toujours d'actualité : `deviceHost` → `.46` (réglage utilisateur) et release 2.0.1 pour Sparkle.

## 2026-08-11 (SunRoad : consommation en courbe continue à la Helios)

### Changed
- **La consommation maison n'est plus en bâtons sous l'arc** (peu lisibles : espacés, uniquement aux heures de jour) mais en **courbe bleue continue sur le cercle horaire complet**, comme Helios : chaque tranche de 5 min est placée à l'azimut du soleil de cet instant (la nuit passe côté nord), la hauteur est proportionnelle aux watts (normalisée sur son propre pic, rayon `domeRadius - 14`), avec des **piquets verticaux translucides** tous les quarts d'heure. Nouveau **badge « ⌂ n W »** face caméra au-dessus de la maison (conso instantanée CT + injection, reconstruit par pas de 10 W). Le ruban de production reste en bâtons turquoise sous l'arc, à l'échelle de son propre pic. Tout suit la checkbox Énergie. Guide fr/en réécrit. 111 tests verts.

## 2026-08-11 (poll local : refuser le payload d'un Smart CT pris pour un SolarFlow)

### Fixed
- **Le poll local « réussissait » sur la mauvaise boîte** : le DHCP a déplacé le Smart CT de `.31` vers `.20`, `deviceHost` a été réglé sur `.20` — et comme les deux appareils exposent la même API `GET /properties/report`, `ZendureParser.parse` (qui n'exigeait aucun champ) transformait le payload du compteur en `DeviceState` tout à zéro affiché comme une mesure réelle : plus de production visible en local, et la sonde de bascule auto « réussissait » aussi → oscillations local (faux) ⇄ cloud (vrai). Garde-fou ajouté : payload contenant `total_power`/`a_aprt_power` → erreur dédiée `notASolarFlow` (« Cette adresse répond comme un Smart CT… »), payload sans aucun des 17 champs signature SolarFlow (`sn`/`rssi` exclus, le CT les publie aussi) → `badPayload`. Un poll sur la mauvaise adresse échoue désormais franchement (watchdog et bascule auto le voient). 2 tests ajoutés, 113 verts. Reste côté réglages : `deviceHost` → `[IP-SolarFlow-1]` (le SolarFlow, vérifié par sonde).

### Decisions
- Diagnostic réseau du jour : SolarFlow toujours en `[IP-SolarFlow-1]` (58 clés, valeurs cohérentes avec le cloud), Smart CT désormais en `[IP-SmartCT]` (sn `61u1m6E3`), `.31` morte. `ctHost = [IP]` est correct ; seul `deviceHost` est à corriger.

## 2026-08-11 (merge + déploiement local des deux changements du jour)

### Changed
- **Merge `--no-ff` sur main et push** (`002162f..a7b548e`) : `fix/smartmeter-history-zero-fields` (`e2c3567`) et `feat/sunroad-consumption-ribbon` (`a7b548e`), 111 tests verts sur main mergé, branches supprimées. **App relancée en build local** : Release + signature Developer ID (procédure release.sh sans DMG/notarisation ; purge de `build/` requise, le cache SPM pointait sur l'ancien chemin `DevApps/SolarTools`), installée dans /Applications, poll vérifié (snapshot 4 s), `homeCurve-<day>` persistée (~2,6 kW — CT actif). ⚠️ Le build 20 en place n'est plus la version notariée : prévoir une **release 2.0.1** pour distribuer via Sparkle.

## 2026-08-11 (SunRoad : ruban de consommation maison le long de l'arc)

### Added
- **Ruban de consommation dans la scène SunRoad** (à la Helios, qui dresse production ET consommation le long du chemin du soleil) : second jeu de bâtons **orange**, en retrait (rayon `domeRadius - 10`) sous le ruban de production turquoise (`domeRadius - 5`), un bâton par quart d'heure à la position réelle du soleil, **échelle commune** (max des deux pics) pour comparer production et consommation d'un coup d'œil. Données : nouvelle courbe 5 min `homeCurve`/`homePeakW` dans `DailyAccumulator` (paramètre `home` d'`ingest`, défaut 0), alimentée dans `Monitor.accumulateEnergy` par `EnergyMath.homeTotal` (Smart CT + injection) quand le CT répond, `outputHomePower` seul sinon — même convention que le schéma de flux. Persistance par jour (`homeCurve-<day>`/`homePeakW-<day>`), purge `pruneAuxKeys` étendue. Guide fr/en `sunroad.md` à jour. Test `testHomeCurveBucketsKeepMax`, 111 tests verts.

## 2026-08-11 (Historique : SmartMeter 3CT enfin masqué — les zéros ne sont pas des données)

### Fixed
- **Le SmartMeter 3CT apparaissait toujours dans l'Historique sans aucune donnée**, malgré les deux correctifs du 2026-08-10. Vraie cause vue dans le cache disque (`Application Support/ZendureMonitor/history/[deviceId].json`) : l'endpoint tdengine lui répond la structure solarFlow **complète** (15 champs : solar, home, batteryInput…) mais avec **toutes les valeurs à 0** — les tests de présence (`totals.isEmpty`, `!fields.isEmpty`) ne le marquaient donc jamais `unsupported`. Fix : nouveau `ZendureAppAPI.hasEnergySignal(_:)` (au moins une valeur non nulle, hors clés méta `type`/`productType`) utilisé partout dans `HistoryService` (sonde des totaux vie entière, jours porteurs, filet après récupération). Au prochain chargement, le 3CT passe `unsupported` et son cache de 91 jours de zéros est purgé. Un SolarFlow neuf sans production serait masqué de même — il réapparaît dès la première valeur non nulle (la sonde se refait à chaque chargement). Test `testHasEnergySignal` ajouté, 110 tests verts.

## 2026-08-11 (capture SunRoad dans la doc)

### Docs
- **Capture d'écran SunRoad** (2200×1520, prise par Vincent sur données réelles : 39 bâtiments, maison ambre, arc horodaté, timeline, sidebar) intégrée à la landing (figure dédiée), en tête des pages guide `fr/sunroad.md`/`en/sunroad.md` (copie `guide/images/sunroad.png`) et dans le README. Branche `docs/2.0-sunroad-screenshot` (`dc57500`) mergée sur main (`002162f`), push. Repéré sur la capture : lettres cardinales E/S en miroir selon l'angle caméra → backlog v2.1.

## 2026-08-11 (release v2.0.0)

### Added
- **Release v2.0.0 (build 20)** : SunRoad. Merge `--no-ff` de `feat/helios-scene` sur main (30 fichiers, +1757/-844), bump via `release/2.0.0`, DMG 4,0 Mo notarisé (Accepted) + agrafé + signé Sparkle, release GitHub `v2.0.0` créée avant le push de l'appcast (`2bb18e9`), asset vérifié HTTP 200. Installée depuis le DMG (procédure lsregister, build 20 confirmé), vérifications indépendantes OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), relancée, poll local vérifié. Branches mergées supprimées. Notes de release : SunRoad complet (quartier OSM, ombres réelles, flux animés, timeline, fusion Soleil, maison au clic), fenêtre Historique (premier vecteur Sparkle pour les utilisateurs 1.11) et reprise après veille. Reste : capture d'écran SunRoad (fenêtre fermée pendant la release — à faire par Vincent, puis intégration landing/guide).

## 2026-08-10 (SunRoad : quartier perdu après le clic-maison ; Historique : SmartMeter)

### Fixed
- **Quartier vide après « Définir ma maison »** (vécu comme « le clic ne marche pas ») : le clic fonctionnait — mais le recentrage changeait la clé du cache (arrondi 1e-4°), déclenchait un refetch Overpass souvent throttlé, et l'écran retombait sur un quartier vide. Deux corrections : bâtiments et routes se **reconstruisent aussi quand l'origine change** (`originKey` — les coordonnées OSM sont absolues, seule la projection bouge : le pick recale la scène instantanément, sans réseau) ; et `loadNeighborhood` **retombe sur le cache voisin** (clé réglages, puis clé effective) quand le fetch échoue.
- **Historique : le SmartMeter apparaissait sans données** — l'endpoint tdengine solarFlow ne le couvre pas. Le service sonde désormais les **totaux vie entière en premier** : totaux vides et aucun jour **porteur de champs** → appareil `unsupported`, masqué de la fenêtre (note discrète) et jamais interrogé sur 365 jours ; les jours vides déjà en cache (récoltés avant ce filtre) ne comptent pas et sont purgés, et un filet après récupération couvre le cas des jours frais tous vides. Un appareil en échec ne condamne plus le chargement des autres (catch par appareil).

## 2026-08-10 (SunRoad : correctifs retour de test — clic-maison et œil)

### Fixed
- **« Définir ma maison » inopérant** : avec `allowsCameraControl`, les gesture recognizers internes de `SCNView` passent avant la surcharge `mouseDown` — le clic de désignation n'arrivait jamais. Remplacé par un `NSClickGestureRecognizer` ajouté à la vue (installé depuis `makeNSView`), qui coexiste avec la caméra orbitale (elle n'utilise que le drag) ; hit-testing inchangé.
- **L'œil ne masque plus que le bandeau** d'informations posé sur la 3D — la timeline et les cartes du panneau latéral restent visibles (demande de Vincent). Libellés d'aide et pages guide FR/EN alignés.

## 2026-08-10 (v2.0 Phase E — fusion Soleil → SunRoad)

### Changed
- **La fenêtre Soleil fusionne dans SunRoad** (décision de Vincent, mise en page validée) : scène 3D plein cadre à gauche, **panneau latéral droit** (332 pt, masquable, persisté) en cartes repliables héritées de Soleil — Champs de panneaux avec **sliders azimut/inclinaison branchés sur la 3D** (le panneau pivote dans la scène pendant le geste), Production (histogramme 14 j + total du jour + pic), Éphémérides, Lumière et crépuscules, Productible théorique, Météo. Le **compas solaire est retiré** (ses informations vivent mieux en 3D). Le bouton soleil orange ouvre SunRoad, le cube indigo disparaît (retour à cinq actions), fenêtre 1400×980.
- `SunView.swift`, `SunCompassView.swift`, `SunCard.swift` supprimés ; `SkyDomeView.swift` conservé (héberge `ArrayPalette`/`PanelGlyph`/`Cardinal`, à dégraisser en 2.1). L'écran « non configuré » renvoie vers Réglages → Soleil (où position et champs restent configurés).

### Added
- **« Définir ma maison » au clic** : menu maison dans le HUD → le clic sur un bâtiment de la scène (`PickableSCNView`, hit-testing sur les nœuds `building-<i>`) fait de son centroïde le **centre exact** (`sunroadHouseLat/Lon`, prioritaire sur les réglages) — projection, détection de la maison, éphémérides et quartier se recalent dessus ; « Revenir à la position des réglages » annule.
- Doc : `soleil.md`/`sun.md` supprimées, `sunroad.md` FR/EN enrichies (sidebar, maison au clic), sommaires renumérotés (12 entrées), navigation recâblée (0 lien cassé vérifié), landing (carte « Sun analytics — now inside SunRoad », section dashboard sans la capture obsolète), README (fusion mentionnée, roadmap). 109 tests verts, build sans warning.

## 2026-08-10 (v2.0 Phases C + D — l'énergie dans SunRoad, timeline, météo, mode mur)

### Added
- **Phase C — l'énergie dans la scène** : `SunRoadFlows` (watts quantifiés en 0–4 billes par palier : ≤150/≤500/≤1200/+), ancres 3D (pylône réseau au nord-est, bloc batterie contre la maison — couche Énergie), **billes émissives animées** à vitesse constante en chapelet décalé sur 4 flux (panneaux→maison jaune, pylône→maison orange, maison↔batterie vert/orange), **ruban de production sur l'arc** (un bâton par quart d'heure à la position réelle du soleil à cet instant, hauteur ∝ W/pic du jour). `Monitor` injecté dans la fenêtre.
- **Phase D — timeline, météo, mode mur** : slider **±48 h** en bas de fenêtre (soleil, ombres, ciel et arc suivent ; bouton « Maintenant » ; ruban masqué hors jour courant), **météo Open-Meteo dans la scène** (couverture nuageuse → lumière directionnelle voilée jusqu'à -55 %, ciel grisé — la nuit reste la nuit), **mode mur** (œil barré → interface effacée, œil discret en rappel), rangée HUD énergie (solaire, maison, SOC, nuages), checkbox « Énergie ».
- **Doc complète v2.0** : pages guide `fr/sunroad.md` + `en/sunroad.md`, sommaires renumérotés (SunRoad en 7, 13 entrées), navigation recâblée (0 lien cassé, vérifié), pages panneau « six actions » (cube indigo), carte « 🧊 SunRoad — your home in 3D » sur la landing, README « New in 2.0 » + roadmap (v2.0 cochée, reliquat 1.13 → v2.1, optimiseur → v2.2). 109 tests verts, build sans warning.

## 2026-08-10 (SunRoad : couches visibles à la carte)

### Added
- **Checkboxes de visibilité dans le HUD SunRoad** : cinq couches activables — Bâtiments (inclut la maison placeholder quand l'OSM n'a pas répondu), Routes, Arc du soleil (l'éclairage directionnel reste toujours actif), Panneaux, Boussole. `SunRoadVisibility` appliquée par `isHidden` sur les conteneurs de la scène (anneau + cardinales regroupés dans un `compassNode`), choix persistés (`sunroadShowXxx`).

## 2026-08-10 (SunRoad : les routes du quartier)

### Added
- **Routes OSM dans la scène SunRoad** (retour de test : « plus de détails dans la 3D ») : la requête Overpass ramène aussi `way["highway"]` (rayon 170 m, un peu plus loin que les bâtiments — elles structurent la vue), largeur déduite de la classe (motorway 9 m → chemin piéton 1,8 m, défaut 4 m), rendu en rubans plats au ras du sol — segments `SCNBox` orientés + disques aux sommets pour arrondir les virages, chemins piétons plus clairs, plus fins et un cheveu au-dessus des chaussées (anti z-fighting), aucune ombre portée. Plafond 200 routes.
- Modèle généralisé `SunRoadNeighborhood { buildings, roads }` : cache disque v2 (suffixe `_v2` — un ancien cache v1 est simplement re-téléchargé), HUD « n bâtiment(s) · m route(s) ». Tests du parseur enrichis (routes à 2 points acceptées, profils de largeur, piéton).

## 2026-08-10 (v2.0 Phase B — le quartier OSM dans SunRoad + renommage)

### Changed
- **Renommage Helios → SunRoad** (demande de Vincent) : `Sources/Helios/` → `Sources/SunRoad/`, types `SunRoadGeometry`/`SunRoadSceneView`/`SunRoadView`, fenêtre `id "sunroad"` titrée « SunRoad », bouton d'en-tête « SunRoad (3D) », tests renommés.

### Added
- **Phase B — le quartier en 3D** (branche `feat/helios-scene`) :
  - `GeoProjection` : projection équirectangulaire pure lat/lon → mètres (est, nord), centroïde et distance d'une emprise — 3 tests.
  - `OverpassService` + `OverpassParser` : emprises `way["building"]` dans un rayon de 120 m via l'API publique Overpass (`out geom`), hauteurs depuis `height` (tolère « 7.5 m », virgule) ou `building:levels` × 3 m (défaut 6 m, plafond 60 m), tri par distance et plafond 250 bâtiments — parseur pur, 3 tests. `SunRoadCache` : JSON par localisation arrondie (1e-4°) dans Application Support — les bâtiments ne bougent pas, un seul fetch.
  - Scène élargie au quartier (dôme 140 m, caméra reculée) : bâtiments extrudés (`SCNShape` basculé au sol, (est, nord, hauteur) → (x, y, -z)), **la maison = le bâtiment le plus proche de la position configurée (< 25 m), surlignée ambre**, placeholder masqué dès que l'OSM répond ; les voisins projettent leurs **vraies ombres portées** sur la scène — le cœur de l'effet Helios.
  - HUD : état du chargement (« n bâtiment(s) du quartier », erreur douce sans réseau — la scène reste utilisable) + bouton « Recharger le quartier ».
  - 108 tests verts, build sans warning.

## 2026-08-10 (v2.0 Phase A — socle Hélios 3D)

### Added
- **Fenêtre « Hélios »** (bouton indigo `cube.transparent`, `Window id "helios"`) — Phase A du plan v2.0 (PLAN.md Phase 13, décisions validées : numéro 2.0, rendu SceneKit) :
  - `Sources/Helios/HeliosGeometry.swift` : mapping pur azimut/élévation → repère 3D SceneKit (Y haut, nord = -Z, est = +X), surface d'un champ depuis sa puissance crête (~200 Wc/m², bornée 1–40 m²), rampe de luminosité jour/nuit (-6° → +15°). 4 tests unitaires.
  - `Sources/Helios/HeliosSceneView.swift` : scène SceneKit — sol, anneau de boussole avec cardinales, maison placeholder (murs + toit, remplacée par l'OSM en phase B), champs de panneaux en plans inclinés (azimut/inclinaison réels de la fenêtre Soleil), arc du soleil du jour (SunCalc.track pas 10 min, segments cylindriques + repères horaires), soleil = sphère émissive + **lumière directionnelle avec ombres portées réelles** (shadow map 2048), ciel et intensités interpolés nuit/crépuscule/jour, caméra orbitale native (orbitTurntable). Arc et panneaux reconstruits seulement quand jour/lieu/champs changent.
  - `Sources/Helios/HeliosView.swift` : HUD (date-heure, élévation, azimut, lever–coucher), horloge 60 s, écran « non configuré » renvoyant vers la fenêtre Soleil (mêmes réglages `sunLatitude`/`sunLongitude`/`sunArrays`).
- Merge préalable de `fix/sleep-wake-recovery` sur main (`1aba549`) après validation du test capot par Vincent — release 1.12.1 pas encore décidée. 102 tests verts, build sans warning. Branche `feat/helios-scene`.

## 2026-08-10 (reprise après veille + checkbox débogage Historique)

### Fixed
- **Mode Cloud mort après une mise en veille** (capot fermé → « no data » jusqu'à un re-clic manuel sur Cloud Zendure). Cause racine : au réveil, la reconnexion relançait `CloudService.start()` alors que le Wi-Fi n'était pas encore remonté ; l'échec HTTP du deviceList posait `.failed` **sans replanifier d'essai** — cul-de-sac définitif. Trois volets :
  - `CloudService` : nouveau `scheduleRetry(message:)`, chemin commun aux coupures MQTT et aux échecs HTTP du deviceList — toute erreur replanifie un `start()` complet 15 s plus tard (le Cloud Key invalide reste un échec net sans retry, c'est déterministe).
  - `MQTTClient` : **timeout sur le PINGRESP** (`awaitingPingResponse`) — après une veille, le socket peut être à moitié mort (aucune erreur signalée, plus aucun trafic) et la session restait « live » sur un flux vide ; désormais un PINGREQ sans réponse au cycle suivant (~30 s) coupe la connexion, ce qui déclenche la reconnexion. Tout paquet entrant réarme le drapeau.
  - `Monitor` : observer `NSWorkspace.didWakeNotification` — 3 s après le réveil (le temps que le Wi-Fi se rattache), redémarrage franc de la session cloud (si mode Cloud) et du cycle de poll, sans attendre le timeout du keepalive.

### Changed
- **Fenêtre Historique** : la carte Débogage est désormais masquée par défaut, derrière une checkbox « Afficher le débogage (échanges HTTP) » (`historyShowDebug`, persisté).

## 2026-08-10 (landing + guide pour la 1.12)

### Docs
- **Landing** (`docs/index.html`) : nouvelle carte « 📈 History window » dans la grille Features (365 jours depuis les serveurs Zendure, métriques par appareil, totaux vie entière, cache local, identifiants Keychain, modes local et cloud).
- **Guide** : nouvelles pages `fr/historique.md` et `en/history.md` (ouverture via l'horloge violette, connexion au compte principal — le Cloud Key ne suffit pas, contenu de la fenêtre, cache et espacement des requêtes, carte Débogage, avertissement API non contractuelle) ; sommaires FR/EN renumérotés (Historique en position 6) ; navigation soleil ↔ historique ↔ widgets recâblée (vérification : 0 lien interne cassé) ; pages panneau : l'en-tête passe à « cinq actions » avec la ligne Horloge violette. Branche `docs/1.12-landing-guide` (`9d56a1c`) mergée sur main (`a0d93ce`), push — Pages redéploie automatiquement.

## 2026-08-10 (release v1.12.0)

### Added
- **Release v1.12.0 (build 19)** : fenêtre Historique. Branche `feature/history-module` mergée `--no-ff` sur main, bump via `release/1.12.0` (`9a6d404`, merge `8a3d6b8`), DMG 3,9 Mo notarisé (Accepted) + agrafé + signé Sparkle, release GitHub `v1.12.0` créée avant le push de l'appcast (`86084a6` avec README « New in 1.12 » + roadmap — v1.12 cochée, reliquat déplacé en v1.13), asset vérifié HTTP 200. Installée depuis le DMG dans /Applications (procédure lsregister, build 19 confirmé), vérifications indépendantes OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), relancée, poll local vérifié (widget-snapshot frais). Branches mergées supprimées.

## 2026-08-10 (module Historique — porté depuis ZendureCloud)

### Added
- **Fenêtre « Historique »** (bouton violet `clock.arrow.circlepath` dans l'en-tête du panneau) : énergie par jour en barres (kWh) sur 7/30/90/365 jours par appareil, sélecteur de métrique (solaire, maison, charge/décharge batterie… — union des clés réellement renvoyées), totaux vie entière, bandeau de progression et carte de débogage HTTP (mot de passe masqué). Module porté depuis l'app exploratoire ZendureCloud.
- **`Sources/Cloud/ZendureAppAPI.swift`** : client de l'API privée de l'app mobile Zendure — la seule voie connue vers l'historique (endpoints tdengine). Login e-mail/mot de passe → jeton Blade-Auth, base régionale reprise du Cloud Key si configuré (sinon EU). Constructeurs de requêtes statiques et purs, testables sans réseau.
- **`Sources/Cloud/EnergyHistory.swift`** : `EnergyDay` (champs bruts clé → valeur, leur liste varie selon le produit), catalogue de libellés FR des métriques, cache disque JSON par appareil (`Application Support/ZendureMonitor/history`) — les jours passés sont immuables, seul « aujourd'hui » est re-téléchargé.
- **`Sources/Cloud/HistoryService.swift`** : orchestration (ObservableObject) — identifiants dans le Keychain (`appAccount`/`appPassword`, chemin totalement séparé du Cloud Key), liste d'appareils autonome (celle du compte app : l'historique fonctionne en mode local comme en mode cloud, sans rapprochement), récupération séquentielle throttlée (150 ms), journal des 50 derniers échanges HTTP.
- 12 tests unitaires portés (`Tests/ZendureAppAPITests.swift`) : forme des requêtes login/énergie, parseurs, redaction du mot de passe, dates. 98 tests verts, build sans warning. Branche `feature/history-module`, ni mergé ni releasé.
- **Build de test installé** dans /Applications : Release signé Developer ID (Hardened Runtime, sans notarisation ni DMG), procédure lsregister + relance détachée ; poll local vérifié (widget-snapshot frais) — la signature stable préserve le grant TCC réseau local, contrairement à un Debug adhoc.

### Changed
- **Métriques par source** (retour de test) : le sélecteur de métrique est déplacé dans chaque carte d'appareil et ne liste que les champs réellement renvoyés par cette source (la liste varie selon le produit — Hub 2000 : 4 champs, Hyper : 5…) ; choix mémorisé par appareil (repli sur « solar » si la clé n'existe plus). Le sélecteur global — union trompeuse des clés de tous les appareils — disparaît des contrôles.

## 2026-08-10 (release v1.11.1)

### Added
- **Release v1.11.1 (build 18)** : patch diagnostic MQTT cloud. Branche `fix/cloud-mqtt-diagnostics` (`9ae8bae`) mergée `--no-ff` sur main, bump via `release/1.11.1` (`4a7fb0e`, merge `c8d5c2c`), DMG 3,7 Mo notarisé (Accepted) + agrafé + signé Sparkle, release GitHub `v1.11.1` créée avant le push de l'appcast (`2d29c7f`), asset vérifié HTTP 200. Installée dans /Applications (procédure lsregister, build 18 confirmé), vérifications indépendantes OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), relancée. Ligne roadmap v1.11.1 dans le README ; notes de release avec le conseil « une seule intégration par Cloud Key ».

## 2026-08-10 (patch diagnostic MQTT cloud — rapport utilisateur 2 SolarFlow)

### Fixed
- **Diagnostic de la boucle « Connexion MQTT perdue : connexion fermée par le serveur »** (rapport d'un utilisateur à deux SolarFlow, cause exacte non confirmée — trois hypothèses instrumentées) :
  - `MQTTClient` parse les **codes de retour SUBACK** (`.suback(returnCodes:)`, corps = packetId + un code/topic) et coupe avec « abonnements refusés par le serveur » si tous valent 0x80 — avant, un refus d'abonnement laissait la session « live » sur un flux vide.
  - `CloudService` détecte la **boucle de session takeover** : ≥ 3 fermetures serveur consécutives < 10 s après une connexion réussie → message dédié expliquant que le cloud Zendure n'accepte qu'une session temps réel par Cloud Key (Home Assistant, ioBroker, app sur un autre Mac…). Champs `lastConnectAt`/`rapidDropCount`, uniquement touchés depuis les callbacks MQTT (queue série).
  - Le **deviceList filtre les entrées aux `deviceKey`/`productKey` vides** avant abonnements et getAll — un topic malformé (`iot//…/#`) peut valoir une fermeture ACL sur EMQX.
- 2 tests SUBACK ajoutés (codes portés, corps sans codes ≠ refus). Tous tests verts. Non commité, non releasé.

## 2026-08-10 (landing + guide pour la 1.11)

### Docs
- **Landing `docs/index.html`** : carte « The full panel » (conso totale, repli des cartes, masquage), carte « Cloud mode & Smart CT » et section « Three connection paths » (bascule automatique 1.11, nouveau point ✓ dédié dans le panneau récapitulatif).
- **Guide FR/EN** : page panneau — carte **Consommation maison** documentée (manquait depuis la 1.10.3, avec les trois états du Smart CT), « cinq cartes », repli 1.11 et section « Cartes du panneau » des réglages ; page cloud — section « La bascule automatique (nouveau en 1.11) » ; page accès distant — note « Et si le VPN tombe ? » renvoyant vers la bascule auto.
- Branche `docs/1.11-landing-guide` (`87fbed4`) mergée sur main (`1cf6d21`), push — déploiement GitHub Pages vérifié (workflow « Deploy GitHub Pages » ok). Installation 1.11.0 reconfirmée sur le Mac (build 17 actif).

## 2026-08-10 (release v1.11.0)

### Added
- **Release v1.11.0 (build 17)** : bascule automatique local ⇄ cloud + cartes repliables/désactivables. Commit unique `afc7e29` sur `feat/auto-switch-and-collapsible-cards` mergé `--no-ff` sur main, bump via `release/1.11.0` (`bfcac6a`, merge `b5bccf5`), DMG 3,7 Mo notarisé (Accepted) + agrafé + signé Sparkle, release GitHub `v1.11.0` créée avant le push de l'appcast (`2b5a3b3`), asset vérifié HTTP 200. Installée dans /Applications (procédure lsregister, build 17 confirmé), vérifications indépendantes OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), relancée.

### Docs
- **README** : paragraphe « New in 1.11 » + roadmap v1.11 cochée, reliquat (outputPower, champs d'erreur zenSDK, localisation chinoise, cartes réordonnables, bouton widget, historique soutirage CT) déplacé en v1.12 ; notes de release `release/release-notes-1.11.0.md` ; TODOS aligné.

## 2026-08-10 (cartes du panneau repliables et désactivables)

### Added
- **Cartes repliables dans le panneau** (demande Vincent, style Juicy) : `MetricCard` gagne `collapseKey` (état persisté dans UserDefaults) et `collapsedSummary` — un clic sur l'en-tête replie/déploie (chevron animé, 0,18 s), et la carte repliée n'affiche que son en-tête + une valeur clé (solaire W, batterie %, flux maison W, conso maison W, historique total kWh). Les usages existants de MetricCard (dashboard, Soleil) restent non repliables (init rétro-compatible, paramètres optionnels).
- **Visibilité des cartes configurable** : nouvelle section Réglages → Affichage → « Cartes du panneau », 5 toggles (`showSolarCard`, `showBatteryCard`, `showFlowsCard`, `showConsumptionCard`, `showHistoryCard`, défaut visible) lus par @AppStorage dans MenuView. Build + tests OK. Non commité, non releasé (en attente avec la bascule auto local ⇄ cloud).

## 2026-08-10 (bascule automatique local ⇄ cloud)

### Added
- **Option « Basculer automatiquement »** (Réglages → Source des données, clé `autoSwitchMode` — demande Vincent depuis la [région], [Mac-collecteur] offline) : en mode local, après **2 polls consécutifs en échec** (hôte principal ET secours) et si une Cloud Key est enregistrée, l'app passe seule en mode Cloud ; en mode Cloud, une **sonde de l'hôte local toutes les 60 s** (timeout 5 s) la fait revenir en local dès que le SolarFlow répond. Le pied du panneau affiche « Connexion : Cloud Zendure — bascule auto » quand le mode Cloud résulte d'une bascule (`Monitor.autoSwitchedToCloud`, non persisté — cosmétique). Nouveaux membres : `autoSwitchMode` (persisté), `localFailureStreak`, `lastLocalProbe`, `autoSwitchBackIfLocalReachable()`. Build + tests OK. Non commité, non releasé.

## 2026-08-10 (release v1.10.4)

### Added
- **Release v1.10.4 (build 16)** : état distinct pour le Smart CT injoignable. Feature branch `feat/smart-ct-unreachable-state` (`81d7b69`) mergée `--no-ff` sur main, bump via `release/1.10.4` (`7fee1b1`, merge `dbd3ad6`), DMG 3,6 Mo notarisé (Accepted) + agrafé + signé Sparkle, release GitHub `v1.10.4` créée avant le push de l'appcast (`d4113f5`), asset vérifié HTTP 200. Installée dans /Applications (procédure lsregister, build 16 confirmé au dump Launch Services), vérifications indépendantes OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), poll local vérifié après relance.

### Docs
- **README** : phrase 1.10.4 ajoutée au paragraphe « New in 1.10.3 » + ligne roadmap v1.10.4 cochée ; notes de release `release/release-notes-1.10.4.md`.

## 2026-08-10 (Smart CT injoignable : état distinct dans l'UI)

### Changed
- **L'interface distingue désormais trois états du Smart CT** (demande Vincent : en mode Cloud à distance, la carte laissait croire qu'aucun compteur n'était configuré) : mesuré → consommation totale ; **configuré mais injoignable** (le CT n'est lisible que depuis le réseau local, jamais relayé par le cloud) → carte Consommation maison en « via SolarFlow seulement » avec un message `wifi.slash` expliquant que le soutirage réseau n'est pas compté et que la valeur est partielle ; non configuré → invitation à renseigner le CT (message inchangé). Légende du schéma de flux du dashboard adaptée de la même façon. Nouveau helper `Monitor.ctConfigured` (hôte CT renseigné). Build Debug OK. Non commité, non releasé.

## 2026-08-09 nuit (release v1.10.3)

### Added
- **Release v1.10.3 (build 15)** : carte « Consommation maison » dans le panneau. Feature branch `feat/menu-home-consumption` (`e657c39`) mergée `--no-ff` sur main, bump via `release/1.10.3` (`e41fc39`, merge `78aa010`), DMG 3,6 Mo notarisé (Accepted, ID `24943509`) + agrafé + signé Sparkle, release GitHub `v1.10.3` créée avant le push de l'appcast (`c2a2e66`), asset vérifié HTTP 200. Installée dans /Applications (procédure lsregister, build 15 confirmé au dump Launch Services), vérifications indépendantes OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), poll local vérifié après relance.

### Docs
- **README** : paragraphe « New in 1.10.3 » (carte Consommation maison) + ligne roadmap v1.10.3 cochée ; notes de release `release/release-notes-1.10.3.md`.

## 2026-08-09 nuit (carte Consommation maison dans le panneau)

### Added
- **Carte « Consommation maison » dans le panneau de la barre de menus** (`MenuView.consumptionCard`, entre Flux et Historique — demande Vincent) : avec un Smart CT configuré, affiche la consommation totale de la maison (soutirage réseau hors charge secteur du SolarFlow + injection SolarFlow) avec le détail par source (LegendRow « Depuis le SolarFlow » / « Depuis le réseau ») ; sans CT, affiche l'injection SolarFlow seule avec une invitation à renseigner le Smart CT dans Réglages → Réseau.

### Changed
- **Calcul de la consommation maison centralisé dans `EnergyMath`** (`gridToHome(ctTotal:gridIn:)` et `homeTotal(ctTotal:gridIn:outputHome:)`) ; `EnergyFlowView` refactorisé pour utiliser ces helpers au lieu de son calcul local. Build Debug OK.

## 2026-08-09 nuit (release v1.10.2 + capture dashboard)

### Added
- **Release v1.10.2 (build 14)** : disposition en X symétrique du schéma de flux. Merges sur main (`50f48b8` layout, `e02577f` bump), DMG 3,6 Mo notarisé (Accepted) + agrafé + signé Sparkle, release GitHub `v1.10.2` créée avant le push de l'appcast (`56d5a8e`), asset vérifié HTTP 200, notes de release commitées (`910accc`). Installée dans /Applications (procédure lsregister), vérifications indépendantes OK (spctl Notarized Developer ID), poll local vérifié après relance.

### Docs
- **`docs/dashboard.png` régénérée** (mergée `dae8967`) : 1640×1958, thème clair, X symétrique avec Smart CT mesuré (liaison verticale Réseau → Maison 455 W, conso totale 835 W), mêmes données synthétiques que la capture 1.10. Harnais reconstruit (CLI nu, Monitor réel : poll neutralisé hôte vide + notifications désactivées avant init, stubs WindowPolicy/Updater, fond opaque). Pièges notés : le 1er cycle de poll efface `ctReport`/`lastError` (réinjecter après ~1,5 s) ; la vue dashboard est verticalement élastique → hauteur fixe 979 pts (fittingSize la sous-estime, sizeThatFits renvoie la hauteur proposée).

## 2026-08-09 nuit (schéma de flux : X symétrique)

### Changed
- **Disposition en X symétrique du schéma de flux** (branche `feat/energy-flow-mirror-layout`, commit 8e33fd3 — demande Vincent) : Panneaux (haut) et Batteries (bas) passent sur la colonne de gauche, en miroir exact de Maison (haut) et Réseau public (bas) à droite, SolarFlow au centre ; la prise hors-réseau pend désormais sous le hub. Le schéma reste planaire — aucun croisement de flux. Tests verts, rendu vérifié via le harnais (light/dark × CT présent/absent × prise active). Non mergée, non releasée.

## 2026-08-09 nuit (release v1.10.1)

### Added
- **Release v1.10.1 (build 13)** : fix découverte Bonjour → IP (`13f2257`) + schéma de flux planaire (`f6594e6`). Merges `--no-ff` sur main (`d72746f` schéma, `2bb272f` bump), push, DMG 3,6 Mo notarisé (Accepted, ID `f0abff0f`) + agrafé + signé Sparkle EdDSA, release GitHub `v1.10.1` créée avant le push de l'appcast (`1e5293f`), enclosure vérifiée HTTP 200.
- Installée dans /Applications (procédure lsregister complète), vérifications indépendantes : `spctl` → Notarized Developer ID, `codesign --deep --strict` OK, `stapler validate` OK, poll local vérifié après relance (`widget-snapshot.json` frais).
- `build/` recréé par release.sh purgé après coup (pas de copie concurrente résiduelle) ; branches `fix/energy-flow-no-crossing` et `release/1.10.1` supprimées après merge.

### Notes
- Reste : régénérer `docs/dashboard.png` (le schéma de flux a changé de disposition).

## 2026-08-09 soir (schéma de flux : plus aucun croisement)

### Changed
- **Schéma de flux d'énergie planaire** (branche `fix/energy-flow-no-crossing`, commit f6594e6) : l'arc Réseau → Maison passait sous le hub et croisait le lien vertical hub → batteries. Réseau public et Maison sont désormais **adjacents sur la colonne de droite** (Maison en haut, Réseau en bas — le compteur est physiquement entre les deux) : leur liaison directe est un segment vertical le long du bord, hors du chemin de tous les autres flux. Prise hors-réseau déplacée en coin bas-gauche ; colonne centrale (Panneaux/SolarFlow/Batteries) décalée à x = 0,42 pour l'équilibre.
- `node()` : placement des libellés explicite (`LabelPlacement` : below / above / titleAbove) — les textes de Maison passent au-dessus de sa pastille pour laisser la liaison verticale dégagée.
- L'arc quadratique `gridToHomeArc` disparaît : le cas mesuré (Smart CT) passe par `link()` comme tout flux réel, le cas non mesuré par `unmeasuredLink()` (segment gris + capsule « ? non mesuré »).
- Note du tableau de bord : « arc gris » → « liaison grise ».
- Vérifié : build OK, 85/85 tests, rendu réel via harnais NSHostingView (light/dark × CT présent/absent × prise active) — aucun croisement dans les 4 captures.

## 2026-08-09 soir (résolution de l'incident « mode local KO, cloud OK » — versions multiples)

### Fixed
- **Mode local de nouveau fonctionnel.** Revue du chemin local (Discovery, fetchReport/fetchWithFallback, ATS `NSAllowsLocalNetworking`, entitlements) : aucun bug — le SolarFlow répondait en 40 ms au `curl`. Cause réelle : une **instance Debug signée adhoc lancée depuis DerivedData** tournait à la place de l'app installée ; chaque rebuild adhoc change la désignation de code, macOS invalide alors silencieusement le grant TCC « réseau local » (le mode cloud, trafic Internet sortant, n'est pas soumis à ce grant — d'où le symptôme asymétrique).
- Assainissement des versions : instances quittées, **1.10.0 installée dans /Applications** depuis le DMG notarisé (spctl : Notarized Developer ID), `lsregister -f` + `killall Dock`, désenregistrement Launch Services des 4 copies fantômes (build/Debug, build/Release, DerivedData, corbeille iCloud), purge de `build/` et DerivedData, copie en corbeille supprimée.
- Vérifié : app relancée, `widget-snapshot.json` réécrit avec des données fraîches du SolarFlow (poll local OK, IP [IP-SolarFlow-1]).

### Notes
- Le DMG 1.10.0 (13h07) précède le merge du fix Bonjour→IP (13h36) : l'app installée découvre encore par nom `.local` (lent). Non bloquant (IP en dur dans les réglages) ; v1.10.1 à cuter.

## 2026-08-09 (fix : hôtes .local inutilisables — la découverte renvoie l'IP)

### Fixed
- **« Détectés mais impossibles à tester/utiliser »** : la résolution getaddrinfo des noms `.local` prend ~5 s sur le réseau de Vincent (requête AAAA muette) — pile au-dessus du `timeoutIntervalForRequest = 5` de l'app, alors que le même appel par IP répond en 40 ms et que la résolution mDNS de l'adresse est instantanée (`dns-sd -G` immédiat). La découverte Bonjour renvoie désormais l'**adresse IPv4 résolue** (déjà présente dans `NetService.addresses`) au lieu du nom d'hôte, avec repli sur le nom si aucune IPv4. Parsing `sockaddr_in` extrait en `DeviceDiscovery.ipv4Address(from:)`, testé (IPv6 ignoré, données tronquées ignorées).
- Réglages de Vincent basculés sur les IP : SolarFlow `[IP-SolarFlow-1]`, Smart CT `[IP-SmartCT-ancienne]` (le poll CT échouait aussi par timeout via `.local`).

### Notes
- Le SolarFlow ne s'annonce que sous `_http._tcp` (nom `Zendure-solarFlow2400Pro-<SN>`), le Smart CT sous `_zendure._tcp` — les deux types restent nécessaires dans le browser.
- Limite connue : une IP peut changer au bail DHCP — si ça arrive, relancer « Rechercher sur le réseau ». Le nom `.local` reste utilisable manuellement pour qui préfère.

## 2026-08-09 (landing : les 3 modes de connexion)

### Docs
- **Section « Local-first » de la landing réécrite en « Three connection paths — your choice »** (mergée `a6fad94`) : trois cartes — Local (hôte principal, le défaut recommandé), Local via VPN (hôte de secours, bascule automatique), Zendure Cloud (optionnel, MQTT temps réel, lecture seule) — avec le pied de connexion du panneau comme fil conducteur ; panel technique recentré (mode local par défaut sans serveur Zendure, découverte Bonjour, Smart CT toujours lu en local) et avertissement sécurité conservé.

## 2026-08-09 (captures d'écran 1.10)

### Docs
- **panel-light/panel-dark/dashboard régénérées** (branche `chore/screenshots-1.10`, mergée `bca52fc`) : pied de connexion dans le panneau, schéma de flux en losange avec l'arc Smart CT mesuré (455 W) et la consommation totale maison (835 W) dans le dashboard. Données synthétiques cohérentes avec les captures 1.9 (612 W, 75 %, SN factice).

### Decisions
- Harnais de rendu : NSHostingView + NSWindow hors écran + `cacheDisplay` — **fond opaque obligatoire à la racine** : sans lui, les textes en couleurs sémantiques hors cartes (en-tête, pied) passent par la couche vibrante que `cacheDisplay` ne capture pas (en-tête/pied invisibles, fond noir). Notifications désactivées dans les defaults du harnais → pas besoin d'un bundle .app (UserNotifications jamais touché).

## 2026-08-09 (release 1.10.0)

### Added
- **Release 1.10.0** (build 12) : mode Cloud Zendure (lecture seule, Cloud Key au trousseau, MQTT temps réel), support du Smart CT (soutirage réseau réel + consommation totale maison, poll local), schéma de flux redessiné (losange aligné, arc Réseau → Maison mesuré/« non mesuré »), pied de connexion dans le panneau, onglet Réglages → Réseau.

### Docs
- README : intro « local-first + mode Cloud optionnel », paragraphe « New in 1.10 », section technique « The optional Cloud mode » (+ renumérotation), arborescence (`Sources/Cloud/`, `SmartCT.swift`), roadmap (v1.10 cochée avec le contenu réel, reports en v1.11).
- Landing : tagline et section « Local-first », carte « ☁️ Cloud mode & Smart CT », carte du schéma réécrite, figcaption du dashboard.
- Guide : nouvelle page `fr/cloud.md` + `en/cloud.md` (mode Cloud pas à pas, Smart CT), index du guide en 11 entrées, intro bilingue actualisée.
- `release/release-notes-1.10.0.md`.

### Decisions
- Versement : merge `--no-ff` de `feat/cloud-mode` sur `main` (`c321637`), poussé avant la release ; appcast publié après la création de la release GitHub (leçon 1.9.0 : éviter le 404 Sparkle).
- Les captures (panel/dashboard) datent de 1.9 — régénération notée en TODO (le nouveau schéma et le pied de connexion n'y figurent pas encore).

## 2026-08-09 (réorganisation des Réglages — branche `feat/cloud-mode`)

### Changed
- **Onglet « Distant » → « Réseau »**, qui regroupe désormais en trois sections courtes le compteur Smart CT (déplacé depuis Appareil), l'hôte de secours et le serveur d'historique 24/7 — l'onglet Appareil ne porte plus que la source de données (Local/Cloud) et le rafraîchissement.
- **Textes d'aide raccourcis** (Cloud Key, Smart CT, accès distant, collecteur) : mêmes informations essentielles, sections nettement moins hautes ; la note du tableau de bord pointe vers Réglages → Réseau.

## 2026-08-09 (pied de panneau : mode de connexion — branche `feat/cloud-mode`)

### Added
- **Pied permanent du panneau barre de menu** : icône + « Connexion : locale — hôte principal », « locale — hôte de secours » ou « Cloud Zendure », avec une pastille verte (dernier cycle réussi) ou orange (en erreur), séparé par un `Divider`.

### Removed
- Bandeau ponctuel « Connecté via l'hôte de secours » (redondant avec le pied) + sa clé de traduction.

## 2026-08-09 (Smart CT intégré — branche `feat/cloud-mode`)

### Added
- **Découverte du Smart CT** : le SmartMeter3CT de Vincent est bien appairé (visible dans l'app Zendure) mais absent de la `deviceList` « HA » et muet sur le broker MQTT du compte (vérifié : sonde 180 s avec abonnements wildcard `#`/`iot/#`/`/+/+/#` — seuls les topics du SolarFlow passent, réponse deviceList brute dumpée). En revanche il **s'annonce en Bonjour** (`_zendure._tcp`, `Zendure-smartMeter3CT-[SN-CT]`) et son **API locale zenSDK répond** : `GET /properties/report` → `{a/b/c_aprt_power, total_power}` (relevé réel : 2089 W sur la phase C).
- **`Sources/SmartCT.swift`** : `CTReport` + `SmartCTParser` (payload à plat, total ou somme des phases, tolérant Int/Double/String) — 3 tests dans `Tests/SmartCTTests.swift` avec le payload réel.
- **`Monitor`** : réglage `ctHost` (persisté), poll du CT à chaque cycle **dans les deux modes et même quand le SolarFlow ne répond pas** (le CT est un appareil distinct) ; échec → `ctReport = nil` pour ne jamais afficher une mesure figée comme un flux réel.
- **Schéma de flux** : quand le CT répond, l'arc Réseau → Maison devient un **vrai flux mesuré** (orange, animé, puissance = `total_power - gridInputPower`) et le nœud Maison affiche la **consommation totale** (réseau + injection SolarFlow) ; sans CT, retour à l'arc gris « non mesuré ». Note sous la carte avec le détail par phase.
- **Réglages → Appareil → « Compteur Smart CT (optionnel) »** : champ hôte, bouton « Détecter sur le réseau » (Bonjour, filtre smartMeter/3CT), bouton « Tester » ; `ctHost` préconfiguré sur l'installation de Vincent via `defaults write`.

### Notes
- Le cloud Zendure ne relaie pas les mesures du CT : hors de la maison (mode Cloud sans LAN), l'arc repasse honnêtement en « non mesuré ».
- Confirmation indirecte du pilotage CT dans le flux cloud : `mode: 12` (smart matching) et consigne `outputLimit` réajustée en continu (1536→1595 W) par le CT.

## 2026-08-09 (refonte du schéma de flux d'énergie — branche `feat/cloud-mode`)

### Changed
- **`EnergyFlowView` redessinée en losange strictement aligné** : Panneaux en haut, SolarFlow au centre, Batteries exactement sous le hub (le défaut d'alignement venait d'un `.position()` appliqué à un HStack composite — les pastilles sont désormais ancrées par leur centre, les libellés positionnés à part), Réseau public à gauche, Maison à droite. Halos pulsés sur les nœuds actifs, même langage animé que la fenêtre Soleil (`SkyDomeView`).
- **Arc gris « non mesuré » Réseau → Maison** : le flux existe électriquement mais n'est mesuré par personne sans compteur en tableau (Smart CT) — il est dessiné explicitement (capsule « ? non mesuré ») au lieu d'être omis, et une note sous la carte explique que la consommation totale de la maison est inconnue. Le nœud Maison porte la mention « + réseau : non mesuré ».
- Pastilles SOC par pack sous la jauge agrégée ; valeur du flux batterie dans le libellé (▲/▼) plutôt qu'en capsule sur le lien court ; la prise hors-réseau n'apparaît que lorsqu'elle débite ; la valeur PV vit dans la capsule du lien (libellé « Panneaux » au-dessus de la pastille).

### Notes
- Vérifié en rendu réel (harnais `ImageRenderer` jetable, light/dark × scénario calme/chargé, données de la sonde cloud) — conformément à la règle « une vue qui compile n'est pas une vue qui marche ». 3 chaînes FR→EN ajoutées.

## 2026-08-09 (mode Cloud — branche `feat/cloud-mode`, non mergée)

### Added
- **Mode Cloud Zendure** en plus du mode API locale (protocole repris du projet validé en réel `~/DevApps/Experimentations/ZendureCloud`) : Authorization Cloud Key (base64 → apiUrl + appKey, découpe au dernier point) → `POST /api/ha/deviceList` signé SHA1 → credentials MQTT → abonnement `/{pk}/{dk}/#` + `iot/{pk}/{dk}/#`, fusion des rapports partiels, poll de secours `getAll` à 60 s.
- **`Sources/Cloud/`** (zéro dépendance externe) : `CloudKey`, `CloudModels` (ZendureDevice, MQTTCredentials host:port), `ZendureAPI`, `MQTTClient`/`MQTTPacket` (MQTT 3.1.1 maison sur Network.framework), `CloudDeviceState` (fusion + conversions d'unités + mapping vers `DeviceState` local), `CloudService` (orchestration, reconnexion 15 s par re-login complet, timer getAll sur queue séparée — piège deadlock documenté), `KeychainHelper` (Cloud Key dans le trousseau, service `fr.lauriat.ZendureMonitor`, jamais UserDefaults).
- **Réglages → Appareil** : Picker « Source des données » (API locale / Cloud Zendure), section Cloud (SecureField, « Tester la clé », statut de phase, appareil suivi si le compte en a plusieurs — clé `cloudDeviceKey`).
- **`Scripts/cloud-probe.swift`** : sonde CLI qui liste les appareils du compte puis dump tous les topics/clés MQTT reçus — pour vérifier ce que le cloud publie réellement (ex. consommation globale maison / soutirage réseau via Smart CT).
- **`Tests/CloudTests.swift`** (20 tests portés de ZendureCloud) : décodage Cloud Key, signature/headers deviceList, paquets MQTT, fusion des rapports partiels, conversions d'unités, mapping `DeviceState`, host:port.

### Changed
- `Monitor` : adaptateur **pull** — la boucle de poll existante lit en mode cloud un instantané fusionné (`cloudSnapshot()`, erreur si absent/périmé > 180 s), si bien que lastError, watchdog, isStale, notifications et widget fonctionnent à l'identique. `maxDt` de l'accumulateur élargi à 180 s en cloud (échantillons datés du dernier rapport MQTT). `localNetworkDenied` neutralisé en cloud.
- `ZendureError` : cas cloud ajoutés (`noCloudKey`, `cloudWaiting`, `cloudStale`, `cloudUnavailable`, `cloudReadOnly`).
- Onglet Contrôle désactivé en mode Cloud (lecture seule — `properties/write` MQTT jamais validé en réel) ; hôte de secours masqué en cloud.
- `project.yml` : sources cloud pures ajoutées à la target de tests ; 33 chaînes FR→EN ajoutées au String Catalog (format compact du fichier préservé).

### Decisions
- **Mono-appareil conservé** (Picker si plusieurs appareils cloud) ; **pull plutôt que stream** (la boucle et le watchdog survivent tels quels) ; **cloud en lecture seule v1** ; **`minSoc` auto-échelle avec seuil 50** (le firmware envoie des dixièmes : 100 = 10 %, mais 20 = 20 % direct reste accepté).

## 2026-08-09 (installation 1.9.0 + ménage du dépôt)

### Changed
- **1.9.0 installée dans `/Applications`** depuis le DMG notarisé (l'app n'étant pas lancée, Sparkle n'avait rien pu proposer). `spctl` sur l'app installée : `accepted, source=Notarized Developer ID`.
- **Réparation Launch Services** : `lsregister -f` + relance du Dock. Vérifié dans le dump : `/Applications/ZendureMonitor.app` est enregistrée en `version: 11.0` (donc le nouveau build, plus l'ancien).
- **Dépôt réduit à `main`** : 5 branches distantes et 5 locales supprimées, après avoir vérifié que `git branch --no-merged main` est vide en local **et** en distant — aucun commit n'existait hors de `main`. Les 11 tags de version (v1.0.0 → v1.9.0) sont intacts.

### Notes
- Plusieurs références distantes que l'on croyait vivantes (`release/1.1.0`, `chore/post-release`, `feat/app-icon`…) étaient déjà supprimées côté GitHub : ce n'étaient que des refs locales périmées, nettoyées par `fetch --prune`.
- La base Launch Services conserve des enregistrements concurrents de l'app : une copie 1.6.0 dans la corbeille iCloud, et les builds de développement 1.7.0 (`build/`) et 1.8.0 (DerivedData). Sans effet sur `/Applications`, mais ce sont autant de candidats au lancement — la copie en corbeille mériterait d'être vidée.
- **Le SolarFlow est toujours absent du réseau** (incident du 2026-08-07, non résolu) : le nom mDNS ne résout pas et un balayage Bonjour de 6 s ne voit aucun service Zendure, alors que le mDNS fonctionne par ailleurs depuis ce Mac. L'autorisation « réseau local » de l'app ne peut donc pas être testée de bout en bout tant que l'appareil n'est pas revenu.

## 2026-08-09 (release 1.9.0)

### Released
- **v1.9.0** — fenêtre Soleil v3. `MARKETING_VERSION` 1.8.0 → 1.9.0, `CURRENT_PROJECT_VERSION` 10 → 11 (c'est ce build number que Sparkle compare, pas la version marketing). DMG signé Developer ID, notarisé, agrafé, signé EdDSA pour Sparkle (3,47 Mo). Release GitHub `v1.9.0` + appcast publié.
- Notes de release `release/release-notes-1.9.0.md` : orientations par champ, dôme céleste, compas, réglage en direct, éphémérides enrichies, écran unique ; et les deux correctifs visibles (façade ouest annonçant 323 W au coucher → 30 W, perte de la puissance crête à la suppression du dernier champ).

### Changed
- README : la fenêtre Soleil v3 passe de « mergée, en attente de release » à « New in 1.9 » ; feuille de route v1.9 cochée, les items restants basculent en v1.10.
- Landing : la carte Soleil porte désormais la mention « Rebuilt in 1.9 » (elle avait perdu tout repère de version en changeant de contenu).

### Verified
- **Vérification indépendante du DMG**, sans se fier au ✅ du script : `spctl -a -t exec -vv` → `accepted, source=Notarized Developer ID`, `codesign --verify --deep --strict` OK, `stapler validate` OK, version 1.9.0 dans le bundle monté.
- **App et widget concordent** en 1.9.0 / build 11 — un désaccord de version entre l'app et son extension ne se voit qu'à la notarisation, cinq minutes plus tard.
- **Ordre de publication choisi pour éviter tout 404 Sparkle** : bump + docs poussés, release GitHub créée avec le DMG, URL du `<enclosure>` vérifiée en HTTP 200 (3 466 768 octets), *puis* appcast poussé. L'appcast étant servi depuis `raw.githubusercontent.com/.../main`, l'ordre inverse (celui que suggèrent les « next steps » du script) exposerait les clients à une URL de téléchargement inexistante.
- Appcast relu en ligne : `sparkle:version` 11 > 10 installé, signature EdDSA et longueur présentes.

### Decisions
- L'app installée en 1.8.0 n'est **pas** remplacée à la main : la mise à jour passe par Sparkle. Un `rm -rf` + `ditto` dans `/Applications` casse l'icône Finder et l'autorisation réseau local (voir mémoire `lsregister-after-app-replace`).

## 2026-08-08 (merge de la fenêtre Soleil v3 sur main + landing/README)

### Docs
- **Landing (`docs/index.html`)** : la carte « Sun window » décrit le dôme céleste, le compas solaire et les marqueurs d'orientation à la place des seules éphémérides ; la figure passe de `max-width:520px` à `900px` (la capture est maintenant en 1800×1224 paysage, elle s'affichait écrasée) avec un `alt` et une légende à jour.
- **README** : la fenêtre Soleil v3 est annoncée comme mergée sur `main` en attente de release (et non plus « next up »), avec les curseurs d'azimut/inclinaison et l'écran unique ; le plan du projet mentionne `SolarGeometry` et le vrai rôle de `SunView` ; feuille de route v1.9 mise à jour.
- **Index du guide** : les deux entrées « fenêtre Soleil » / « Sun window » listaient encore les seules éphémérides.

### Verified
- Équilibre des balises de `docs/index.html` contrôlé au parseur avant commit (aucune balise non fermée).
- Merge `--no-ff` sur `main` (20 fichiers, +2586/−240), poussé en `91575b5`. CI et déploiement Pages déclenchés.

## 2026-08-08 (fenêtre Soleil : réglage direct des orientations + tout sur un écran, branche feat/sun-panel-orientations)

### Added
- **Curseurs d'azimut et d'inclinaison dans la carte « Champs de panneaux »** de la fenêtre Soleil : un champ se réoriente sans passer par les réglages, et le dôme, le compas, l'incidence et le productible suivent le geste. Écriture immédiate dans le stockage partagé, donc les réglages affichent la même valeur.
- Infobulles (`.help`) portant l'explication longue des cartes dont la légende a été raccourcie.

### Changed
- **Mise en page en trois bandes** : bandeau d'indicateurs pleine largeur, puis dôme + compas, puis trois colonnes (champs de panneaux | éphémérides + productible | lumière + météo). Fenêtre par défaut 1400×980 (contre 900×780) : le contenu demande 927 pt pour 952 pt disponibles, donc **plus de défilement** — vérifié aussi à trois champs de panneaux. Le `ScrollView` est conservé comme filet (beaucoup de champs, texte agrandi, petite fenêtre).
- Le compas suit la hauteur du dôme au lieu de laisser un vide sous sa carte.
- La ligne d'un champ affiche le point cardinal et la puissance crête ; les degrés se lisent sur les curseurs.
- 9 chaînes localisées ajoutées (FR+EN), 3 devenues mortes retirées — clés vérifiées via `SWIFT_EMIT_LOC_STRINGS` avant écriture.

### Fixed
- **Le premier réglage d'orientation d'un utilisateur v1.8 était perdu** : `arrays` reconstruisait le champ hérité de `sunPeakWatts` à chaque lecture, donc avec un nouvel `UUID`, et la liaison par identité ne retrouvait pas sa ligne. La liste migrée est désormais matérialisée dans le stockage à l'ouverture de la fenêtre.

### Verified
- `xcodebuild` OK, **60 tests verts**. Rendus hors app relus en clair, sombre et en anglais, à deux et trois champs ; hauteur du contenu mesurée par le harnais (927 pt < 952 pt).
- Nouveau test `testStoreRoundTripsEverySliderStepExactly` : chaque cran des deux curseurs (73 azimuts × 7 inclinaisons) traverse l'encodage JSON et revient **au bit près**. C'est la garantie que la poignée ne sautille pas et se pose là où on la lâche — le curseur relit la valeur depuis le stockage au rendu suivant.
- Coût d'un glissement de curseur mesuré (72 crans) : modèle 0,06 ms/cran, écriture du stockage 0,2 ms/cran, **redessin complet 60 ms/cran en layout forcé** — borne haute, car SwiftUI regroupe les rendus lors d'un vrai glissement. À confirmer par un glissement réel (Vincent).

## 2026-08-08 (fenêtre Soleil v3 — orientations des panneaux + dôme animé, branche feat/sun-panel-orientations)

### Added
- **`SolarGeometry`** (Sources/Shared, Foundation pur, 12 tests) : `PanelArray` (nom, Wc, azimut, inclinaison), `PanelArrayStore` (JSON dans UserDefaults + migration douce de `sunPeakWatts`), cosinus d'incidence, facteur plan-des-panneaux (85 % direct pondéré incidence × transmittance atmosphérique de Meinel + 15 % diffus selon la part de ciel vue), productible et énergie ciel clair par champ, meilleure heure, contour d'iso-incidence 3D, masse d'air, longueur d'ombre.
- **`SunCalc` étendu** (signatures existantes inchangées — `OutageWatchdog` en dépend) : `track()` (course du jour échantillonnée), `crossings(atAltitude:)` et `twilight()` (crépuscules civil/nautique/astronomique + heure dorée), `declination()`, `nextSolarEvent()` (prochain solstice/équinoxe par bissection). 4 tests de plus.
- **`SkyDomeView`** : dôme céleste animé — ciel dégradé selon l'élévation (nuit étoilée → heure dorée → plein jour), course du jour heure par heure (portion parcourue vive, reste atténué), arcs des deux solstices, production mesurée posée sur l'axe des azimuts, marqueurs d'orientation avec écart d'incidence et halo quand le champ est aligné, soleil à halo pulsé et couronne de rayons tournante.
- **`SunCompassView`** : compas polaire (centre = zénith) avec course du jour, solstices, et contours d'iso-incidence 25°/50° réels autour de la normale de chaque champ.
- **Fenêtre Soleil réécrite** : bandeau de 5 indicateurs, dôme en héros, compas, carte détaillée par champ (productible, incidence, part de l'irradiance captée, meilleure heure, potentiel du jour), éphémérides enrichies (delta de durée du jour à la seconde, prochain solstice/équinoxe), carte « Lumière et crépuscules », productible (énergie du jour vs potentiel, masse d'air, ombre), météo (facteur nuages explicite). Fenêtre passée en `ScrollView`, `defaultSize` 900×780 (elle était à 540×680 alors que le contenu imposait 760 de large).
- **Réglages → Soleil** : éditeur multi-champs (nom, Wc, azimut avec libellé cardinal, inclinaison), ajout/suppression, total crête. `sunPeakWatts` reste synchronisé sur le total installé.
- 74 chaînes localisées FR/EN + 18 traductions anglaises qui manquaient depuis toujours sur cette surface (météo, éphémérides) ; 9 clés de l'ancienne UI Soleil retirées.

### Fixed
- **Modèle de productible** : un champ orienté plein ouest annonçait sa pleine puissance au coucher du soleil (323 W à 1,6° d'élévation) — la traversée d'atmosphère manquait, il annonce désormais 30 W.
- **Perte de données dans les réglages** : supprimer tous ses champs écrasait `sunPeakWatts` à 0, effaçant sans retour la puissance crête saisie sous v1.8. La clé n'est plus écrite que lorsque le total est non nul.
- **Mise en page de l'éditeur de champs** : dans un `Form` groupé, le `VStack` de chaque ligne était éclaté en lignes séparées (le nom devenait un libellé, les curseurs se retrouvaient orphelins, le `Divider` créait une ligne vide). Reconstruit en une ligne d'en-tête pleine largeur + deux `LabeledContent` — défaut visible seulement en rendant la vue, pas à la compilation.
- **`xcodebuild test` échouait avant de lancer les tests** : la cible `ZendureMonitorTests` n'avait pas d'`Info.plist` et ne pouvait donc pas être signée (`GENERATE_INFOPLIST_FILE: YES` ajouté dans `project.yml`).
- Course du soleil et arcs des solstices étaient tracés dans des repères d'azimut différents (dépliage indépendant) : recalage sur un domaine commun.
- Le soleil était placé par progression temporelle linéaire sur un demi-cercle décoratif ; il l'est maintenant par son élévation et son azimut réels.
- Compas : lettres cardinales rognées par le bord du cadre.

### Changed
- Section « Champs de panneaux » extraite de `SunSettingsTab` vers `Sources/Components/PanelArraysSection.swift` (c'est la seule partie des réglages qui porte une vraie logique d'état) ; `SunSettingsTab` passe de `private` à interne pour que le harnais de capture du guide puisse la rendre hors de l'app.
- `SunView` ne calcule plus les arcs des solstices deux fois par rendu (dôme + compas partagent le même calcul).

### Docs
- `docs/guide/fr/soleil.md` et `docs/guide/en/sun.md` réécrits (dôme, compas, champs de panneaux, lumière, modèle) ; captures `sun-light.png` et `settings-sun.png` régénérées (harnais `NSHostingView` — le cycle de vie SwiftUI tourne vraiment, donc la carte météo est remplie, ce qu'`ImageRenderer` seul ne permet pas).
- Comportement de la suppression de tous les champs documenté dans les deux guides.

### Verified
- `xcodebuild` OK, **59 tests verts** (41 → 59), rendus hors app inspectés à 7 h/10 h/13 h/17 h/20 h/23 h, fenêtre entière vérifiée en clair, sombre et en anglais.
- Onglet **Réglages → Soleil exécuté pour de vrai** dans le harnais (pas seulement compilé) : migration v1.8 (1 200 Wc → un champ plein sud 30°, persisté en JSON), puis suppression du dernier champ via son bouton corbeille → `sunArrays = []` et `sunPeakWatts` conservé à 1 200. Non exercé : le bouton « Ajouter un champ » et les curseurs (dessinés par SwiftUI sans vue AppKit pilotable).

## 2026-08-07 (alertes de panne — branche feat/outage-alerts, suite incident SolarFlow)

### Added
- **`OutageWatchdog`** (Sources/Shared, struct pure + 8 tests — 40/40 verts) : détection « appareil injoignable depuis N min » et « production+injection nulles alors que le soleil est haut ».
- **Notification « SolarFlow injoignable »** (activée par défaut, seuil réglable 5–60 min, défaut 10) — une par épisode de coupure, réarmée à la reprise.
- **Notification « Production solaire anormale »** (activée par défaut) : appareil qui répond mais 0 W produit/injecté pendant 30 min avec soleil > 20° (élévation SunCalc locale ; désactivée si position non configurée).
- **Icône barre de menu ⚠️ « hors ligne »** quand le seuil injoignable est dépassé (au lieu du seul grisage discret du panneau).
- Réglages : section « Alertes de panne » dans l'onglet Notifications ; 12 chaînes localisées FR/EN (insertion chirurgicale dans le catalogue, 36 lignes).

### Released
- **v1.8.0** (build 10) : PR #17 mergée (CI verte), DMG signé/notarisé/staplé (spctl : Notarized Developer ID), release GitHub, appcast Sparkle, installée dans /Applications (lsregister + relance). README roadmap : v1.8 cochée, reste déplacé en v1.9.

### Context
Incident 2026-08-07 : SolarFlow en défaut (batterie pleine, injection coupée) puis totalement hors réseau — l'app n'avait aucune alerte pour ce cas. Reste en attente du retour du device : dump du payload réel pour parser les champs d'état/erreur zenSDK (volet c).

## 2026-08-06 (release 1.7.0 + documentation + sites)

### Added
- **Release v1.7.0** (build 9) : PR #16 mergée, DMG signé/notarisé/staplé, release GitHub, appcast Sparkle, installée dans /Applications (lsregister -f), vérification indépendante `spctl` OK (« Notarized Developer ID »).
- **Documentation complète** : guide utilisateur bilingue FR+EN dans `docs/guide/` (10 pages × 2 langues, captures), README enrichi, wiki GitHub alimenté.
- Notes de release 1.5.0 et 1.6.0 enfin committées dans `release/`.

### Fixed
- **Build GitHub Pages réparé** : les builds Jekyll « legacy » échouaient depuis le commit v1.6.0 (la landing ne se mettait plus à jour) → `docs/.nojekyll` ajouté, puis bascule complète sur un **workflow Actions** (`.github/workflows/pages.yml`, `build_type=workflow`) car le builder legacy restait planté. Cause racine finalement identifiée : **panne partielle GitHub (« Incident with Actions »)** en cours ce jour-là — le déploiement Actions a été relancé après résolution.

### Sites
- **lauriat.fr** : carte Zendure Monitor déplacée de « Productivité macOS » vers la catégorie **Domotique** (créée un peu plus tôt dans la journée avec Hayward Monitor par une autre session), `llms.txt` actualisé pour 1.7.0 (fenêtres Tableau de bord/Soleil, météo, widget large) — commit + push + déploiement FTP des 2 fichiers.
- **vincentlauriat.github.io** : description de la carte ZendureMonitor rafraîchie (dashboard animé, fenêtre Soleil + météo, widgets 14 j) — push.

## 2026-08-06 (vague 2 du backlog — branche feat/todos-wave-2, PR #16)

### Added
- **Widget large (systemLarge)** : en-tête solaire/batterie/maison, sparkline, histogramme 14 j en pur SwiftUI (`MiniBars`), total + « aujourd'hui ». `WidgetSnapshot.dailyEnergy` optionnel (rétro-compatible). Bouton rafraîchir (AppIntents) reporté.
- **Météo fenêtre Soleil** : `WeatherService` (Open-Meteo, sans clé, cache 30 min) — conditions actuelles (code WMO → symbole SF), couverture nuageuse, ensoleillement prévu, productible ajusté nuages (facteur Kasten-Czeplak) dans une carte « Météo locale ».

### Changed
- **`DailyAccumulator`** (Sources/Shared) : logique des cumuls du jour extraite de `Monitor` en struct pure (dt borné, rollover minuit local, buckets 5 min, pic, cumuls solar/stored/grid, fusion collecteur) + **8 tests** — 28/28 verts. `Monitor.accumulateEnergy` devient un adaptateur. Clôt le volet « tests Monitor » du backlog.

### Fixed (bis)
- **Facteur nuages corrigé** (signalement Vincent) : exposant Kasten–Czeplak 3 → **3,4** ; calcul extrait dans `EnergyMath.cloudFactor` (borné 0–100 %) + 4 tests — 32/32 verts (commit `885b5b1`).

### Fin de session (état à la coupure)
- **PR #16 ouverte** (CI verte, 4 commits : widget large, météo, DailyAccumulator, refonte Soleil + fix nuages) — en attente merge Vincent, puis release 1.7.
- **/Applications = build vague 2 signé manuellement** (pour test réel) — restaurer 1.6.0 via `release/ZendureMonitor-1.6.0.dmg` si besoin, ou release 1.7 après merge.
- **[Mac-collecteur] endormi** (Tailscale `rx 0` via relay) : aucun accès distant possible — à réveiller/configurer anti-veille sur place (`sudo pmset -a sleep 0 displaysleep 10`). Le test réel de la vague 2 (polling local) reste à faire au retour à la maison.

### Changed (bis)
- **Fenêtre Soleil repensée** (demande Vincent : « il faut scroller et ce n'est pas bien ») : plus de ScrollView — fenêtre large (820×540), graphique course du soleil × production en héros, puis Éphémérides · Productible · Météo en 3 colonnes. L'arc de la SunCard (redondant avec le héros) disparaît de cette fenêtre ; SunCard ne sert plus qu'à l'état non configuré (invite position).

### Decisions
- Reportés pour arbitrage Vincent : optimiseur HC/HP (plan dédié — pilote la vraie batterie), 中文, cartes réordonnables.
- Copie Debug non signée → autorisation réseau local instable (deux copies même bundle ID) ; en cours de diagnostic, contournement possible : installer le build signé vague 2 dans /Applications pour tester.

## 2026-08-06 (release v1.6.0)

### Fixed (post-install v1.6.0)
- Retour à la maison (Tailscale coupé) : l'app ne voyait plus le SolarFlow en Wi-Fi local et l'icône avait disparu du Finder. Cause : inscription LaunchServices périmée après le remplacement `rm -rf`+`ditto` dans /Applications — nehelper n'appliquait plus l'autorisation TCC « réseau local » au nouveau bundle (via Tailscale/utun ça marchait, cette autorisation ne s'applique pas au VPN). Ni le toggle Réglages ni `killall nehelper` n'ont suffi ; **`lsregister -f` + relance de l'app** a tout réparé (polling + icône). Leçon consignée en mémoire pour toutes les futures installs.

### Released
- **v1.6.0** (build 8) : DMG signé Developer ID, notarisé (Accepted, staplé, vérifié `spctl` → Notarized Developer ID), signé Sparkle EdDSA. Release GitHub `v1.6.0` avec notes, `appcast.xml` + bump versionnés sur main (`94bdacc`), README à jour (`d7c539b`). Version notarisée installée dans /Applications et relancée. Contenu : répartition solaire du jour (panneau + dashboard), résilience hors ligne, fallback VPN mémorisé, debounce polling, jour local, icônes colorées, EnergyMath + 9 tests.

## 2026-08-06

### Decisions
- Branche `fix/code-review-corrections` créée, commit unique `0608525` (5 corrections + icônes colorées), poussée sur origin. **PR #14 mergée sur main** (CI verte), branche supprimée.
- Le « taux d'autoconsommation » strict est impossible sans compteur maison : le hub ne voit pas la consommation aval. Métrique retenue à la place : répartition de la production (direct/stocké) + cumul réseau, déduites des flux du hub.

### Added (branche feat/daily-energy-split)
- **Répartition solaire du jour** dans la carte Flux : « Solaire du jour : X % direct · Y % stocké » + cumul « Réseau : Z kWh » si tirage. Accumulation Wh persistée par jour (`storedWh-<day>`, `gridWh-<day>`, purgées comme les autres clés). La part stockée déduit la charge secteur (`EnergyMath.solarToBattery`, bilan de flux du hub).
- **`Sources/Shared/EnergyMath.swift`** : logique pure extraite (première brique des tests Monitor) + **9 tests unitaires** (charge solaire/AC/mixte, bornes, ratio) — 20/20 tests verts.
- Ligne « Solaire du jour » ajoutée aussi à la carte Production solaire du **tableau de bord** (Vincent ne l'avait pas vue : elle n'était que dans le panneau). PR #15 mise à jour (`0bbbea1`).
- **PR #15 mergée sur main** (`cfda895`, CI verte, rendu validé par Vincent), branche supprimée.

### Fixed (revue de code — 5 corrections validées par Vincent)
- **Debounce du polling** : le champ hôte et le slider d'intervalle relançaient le poll à chaque frappe/cran (adresses partielles interrogées). `scheduleRestart()` attend 800 ms de calme avant de relancer.
- **Hôte de secours mémorisé** : une fois basculé sur le fallback (VPN), l'app reste dessus et ne reteste l'hôte principal que toutes les 2 min — avant, chaque poll payait le timeout de 5 s du principal. Retour immédiat au principal après modification de l'hôte (reset dans `restart()`).
- **Données conservées hors ligne** : en cas d'échec réseau > 60 s, le panneau ne retombe plus sur « Pas de données » — il garde les dernières valeurs grisées (opacité 0,55) avec « Hors ligne — dernières données à HH:MM:SS » en orange dans l'en-tête (`MenuView.isStale`), même pattern que le widget.
- **Jour local, pas UTC** : `Monitor.dayKey` utilisait ISO8601 (UTC) — les compteurs du jour basculaient à 1–2 h du matin. Remplacé par un DateFormatter `yyyy-MM-dd` en fuseau local, cohérent avec la courbe 5 min et l'historique.
- **Zéro warning de build** : captures `self` non-Sendable corrigées dans `PermissionsStatus.refresh()` (guard let + capture forte) et `CFBundleVersion`/`CFBundleShortVersionString` du widget alignés sur l'app dans `project.yml` (7 / 1.5.0). Tests : 11/11 verts.

### Changed
- Icônes d'action de l'en-tête du panneau (tableau de bord, Soleil, réglages, menu ⋯) passées de `.secondary` à `.primary` pour une meilleure visibilité (demande Vincent). Build Debug relancé.
- Puis une couleur distincte par icône (demande Vincent) : tableau de bord bleu, Soleil orange, réglages teal, menu ⋯ reste `.primary` (`headerButton` prend désormais un paramètre `color`).

## 2026-08-05 (release v1.5.0)

### Released
- **v1.5.0** (build 7) : DMG signé Developer ID, notarisé (Accepted, staplé, vérifié `spctl` → Notarized Developer ID), signé Sparkle EdDSA. Release GitHub `v1.5.0` avec notes, `appcast.xml` mis à jour sur main (commit 87c8777). Version notarisée installée dans /Applications (widget réenregistré). Contenu : schéma de flux hub, fenêtre Soleil, panneau style Juicy, réglages réorganisés, sélecteur de période, stats, notifications optionnelles, économies €/CO₂, checks d'autorisations, tests + CI.

## 2026-08-05

### Docs
- Captures d'écran régénérées via harness ImageRenderer avec données réalistes : `docs/panel-light.png`, `panel-dark.png` (nouveau panneau style Juicy — réplique statique `ShotMenuView` car ImageRenderer rend les contrôles AppKit en 🚫), `dashboard.png` (schéma hub), **nouveau `docs/sun.png`** (fenêtre Soleil). README : paragraphe « New in 1.5 », section Sun window, layout Sources/Tests à jour, roadmap v1.5 [x] + v1.6/v2.0. Landing page : cartes features (période/stats, dashboard hub, fenêtre Soleil, notifications), nouvelle section dashboard + Soleil avec captures.
- `SunView` refactorée en `SunView` + `SunContent` (ScrollView séparé — requis par ImageRenderer, même pattern que DashboardContent).

### Changed (ergonomie — demande Vincent)
- **Panneau façon Juicy** : en-tête avec icône + « Zendure Monitor » + heure de mise à jour, et les actions en boutons-icônes en haut à droite (tableau de bord, Soleil, réglages, menu ⋯ pour mises à jour/quitter). La rangée de boutons texte en bas et le gros bouton « Ouvrir le tableau de bord » disparaissent ; le bas du panneau ne sert plus qu'aux avertissements (hôte de secours, erreurs, TCC, notifications).
- **Réglages réorganisés** : nouvel onglet **Soleil** (Position + Panneaux/puissance crête), Rafraîchissement déplacé dans **Appareil**, **Général** allégé (login + Économies + Autorisations, déplacé en dernier), largeur 500 pt — chaque onglet garde une hauteur ajustée à son contenu (`fixedSize` vertical).

### Added (vague 1 du backlog TODOS)
- **Fenêtre « Soleil » dédiée** (le tableau de bord reste un tableau de bord — demande Vincent) : scène Window "sun", bouton « Soleil » dans le footer du panneau, SunCard retirée du dashboard. Politique Dock partagée entre fenêtres via compteur `WindowPolicy`. **Module Soleil v2** : carte « Course du soleil et production » (arc + aire jaune de la courbe du jour sur le même axe temporel lever→coucher, soleil positionné en temps réel) et carte « Productible théorique » (puissance crête paramétrable × sin(élévation) × 0,9, production mesurée, rendement estimé).
- **Sélecteur de période** sur le graphe principal du panneau : 15 min / Jour / 14 j. Courbe du jour = max par tranche de 5 min, persistée par jour (`solarCurve-<day>`, purge > 15 j).
- **Statistiques** : pic de puissance du jour (persisté `peakW-<day>`) et comparaison avec hier (%), affichés sous l'histogramme du panneau et du dashboard.
- **Notifications optionnelles** (opt-in, Réglages → Notifications) : batterie pleine (au plafond socSet), tirage réseau > 50 W alors que le solaire produit > 100 W (max 1/h), record de production battu (1/jour).
- **Économies** : prix du kWh et facteur CO₂ paramétrables (Réglages → Général) ; « Économie du jour » dans la carte Production et total « ≈ X € · Y kg CO₂ évités » dans l'historique du dashboard.
- **Tests + CI** : cible `ZendureMonitorTests` sans host app (9 tests : parser nested/flat/string/sentinelle/décharge, SunCalc solstice Ajaccio/nuit polaire/nuit, Format) — `Format` déplacé dans `Sources/Shared/`. Workflow GitHub Actions `.github/workflows/ci.yml` (xcodegen + build + test sur chaque PR et push main). Tous verts en local.

### Fixed
- Bouton « Utiliser la position de ce Mac » qui tournait indéfiniment : cause = aucun timeout et aucun pré-contrôle — si le Service de localisation macOS est coupé globalement, `requestWhenInUseAuthorization()` ne produit aucun callback. `LocationFetcher` v2 : pré-contrôle `locationServicesEnabled()` (hors main thread), timeout 25 s, messages distincts (service coupé / refus / pas de fix / silence de locationd) — plus jamais d'attente infinie.

### Added
- Vérification des autorisations en amont (demande Vincent) : section « Autorisations » dans Réglages → Général (Réseau local — état inféré des polls, macOS n'a pas d'API —, Localisation, Notifications, avec boutons vers les bons panneaux) + avertissement au démarrage dans le panneau si l'alerte batterie est activée mais les notifications refusées (`Monitor.notificationsDenied`).
- Double-clic sur n'importe quel graphique du panneau (sparklines solaire/batterie/maison, histogramme) → ouvre le tableau de bord (modifier `openDashboardOnDoubleClick`, tooltip d'aide).
- Bouton « Utiliser la position de ce Mac » (module Soleil) : `LocationFetcher` CoreLocation one-shot (précision km, autorisation demandée au clic seulement), disponible dans Réglages → Général et dans la carte Soleil tant que la position n'est pas définie. Clés `NSLocation*UsageDescription` ajoutées dans `project.yml` (⚠️ Info.plist est généré par xcodegen — toute clé doit passer par `project.yml`, un edit direct est écrasé par `xcodegen generate`).
- Schéma de flux v3 (demande Vincent) : le **SolarFlow redevient le hub central** (cercle teal avec température) et les **batteries deviennent un satellite** (anneau SOC compact, lien qui change de sens selon charge/décharge), aux côtés de 4 autres périphériques : Panneaux, Maison, Réseau public et **Prise hors-réseau** (nouveau champ parsé `gridOffPower` → `DeviceState.offGridPower`, repéré dans le rapport réel du device). Liens radiaux animés uniquement quand le flux existe, watts en pastille.
- **Module Soleil** : `SunCalc` (algorithme NOAA 100 % local, précision ~1 min — lever/coucher à -0,833°, midi solaire, durée du jour, élévation/azimut, élévation max) + carte `SunCard` dans le tableau de bord (arc de course du soleil avec position actuelle, recalcul chaque minute) + réglage latitude/longitude dans Réglages → Général (`sunLatitude`/`sunLongitude`, jamais transmis). Carte masquée derrière un message d'aide tant que la position n'est pas renseignée. Vérifié par harness : éphémérides cohérentes pour la [région] début août.
- Détection du blocage TCC « réseau local » (demande Vincent après que le remplacement de l'app dans /Applications a cassé le grant) : `Monitor.looksLikeLocalNetworkDenial` inspecte la chaîne d'erreurs (POSIX 50 ENETDOWN — signature TN3179 du refus —, POSIX 65, -1009/-1004/-1003) et publie `localNetworkDenied`. Nouveau composant `LocalNetworkHint` (bandeau orange, formulé au conditionnel) affiché dans le panneau et le tableau de bord : bouton « Ouvrir les réglages… » (deep link `x-apple.systempreferences…Privacy_LocalNetwork`) + « Réessayer ». i18n FR/EN.

### Changed
- Schéma de flux d'énergie repensé (retour Vincent : « on a l'impression que les batteries fournissent tout le temps de l'énergie ») : les flux sont décomposés à partir du bilan de puissance (solaire → batterie, solaire → maison par l'arc du haut sans transiter par la batterie, batterie → maison, réseau → batterie, réseau → maison par l'arc du bas). Chaque lien ne s'anime que si son flux réel est > 1 W et affiche sa puissance dans une pastille ; le nœud central est désormais étiqueté « Batterie ». Vérifié par harness ImageRenderer (3 scénarios : solaire+charge, décharge nocturne, charge secteur).
- Lancement du tableau de bord plus visible : bouton pleine largeur `.borderedProminent` « Ouvrir le tableau de bord » dans le panneau (remplace le petit bouton texte du footer).
- L'app apparaît dans le Dock et Cmd-Tab (avec son icône) tant que la fenêtre Tableau de bord est ouverte : bascule `NSApp.setActivationPolicy(.regular)` à l'ouverture, retour `.accessory` à la fermeture (l'app est LSUIElement).

## 2026-08-04 (v1.4.0 : tableau de bord + collecteur)

### Added
- Fenêtre « Tableau de bord » (scène Window, bouton dans le panneau) : `EnergyFlowView` (schéma de flux animé — pointillés défilants dont la vitesse suit la puissance, nœud central SolarFlow avec anneau SOC), cartes Production/Batterie/Appareil/Historique enrichies. Nouveaux champs parsés : hyperTmp (°C), remainOutTime (min, 59940 = indisponible), rssi, BatVolt, socSet/minSoc (0,1 %).
- Collecteur 24/7 (`Scripts/collector/`) : python stdlib (poll 30 s → SQLite → API JSON /daily /today /recent /health, port 8899), LaunchAgent déployé sur [Mac-collecteur]. App : réglage « Serveur d'historique », fusion serveur/local (max par jour), badge « collecteur 24/7 ».
- Correctifs v1.4 : baseline 0 sur la sparkline batterie, debounce + confirmation 0 W dans Contrôle, message « aucun appareil trouvé », widget grisé si données > 15 min.

### Blocked
- ⚠️ Le collecteur sur [Mac-collecteur] est bloqué TCC « réseau local » (`No route to host` errno 65 depuis le LaunchAgent python, alors que curl passe en SSH — les sessions SSH sont exemptées). Attente : Vincent doit autoriser python3/le prompt réseau local sur [Mac-collecteur] (partage d'écran). Plan B si pas de prompt : LaunchDaemon root.

### Learned
- ImageRenderer ne rend pas l'intérieur d'un ScrollView → séparer le contenu (DashboardContent) de son ScrollView.

## 2026-08-04 (accès distant Tailscale opérationnel)

### Added
- Tailscale standalone (1.102.1) installé sur [Mac-collecteur] (Mac mini toujours allumé, 192.168.x.39) et sur le MacBook. [Mac-collecteur] = subnet router : `--advertise-routes=192.168.x.0/24` (posé en SSH via la CLI de l'app), route approuvée dans la console d'admin. Hôte de secours `[IP-SolarFlow-1]` configuré dans l'app.
- Clé SSH du MacBook autorisée sur [Mac-collecteur] (installée via partage d'écran — le SSH par mot de passe refusait).

### Learned
- La CLI Tailscale de l'app GUI échoue en SSH (« CLIError error 1 ») tant que l'utilisateur n'est pas authentifié dans la session graphique ; elle fonctionne ensuite, y compris `set --advertise-routes`.
- Vérifier une approbation de route côté serveur : `tailscale status --json` → `Self.AllowedIPs` doit contenir le sous-réseau (l'annonce locale `AdvertiseRoutes` ne suffit pas).

## 2026-08-04 (v1.3.1 release, PR #11)

### Released
- v1.3.1 (build 5) : icône d'app. DMG 2,2 M notarisé + staplé, release GitHub, appcast à jour. Installée dans /Applications, vérifiée (Gatekeeper accepted, version 1.3.1, ~1 kW en direct).

### Learned
- Après remplacement de l'app dans /Applications, PluginKit peut perdre l'enregistrement du widget : `pluginkit -a <appex>` le réenregistre immédiatement.

## 2026-08-04 (icône, PR #10)

### Added
- Icône d'app : soleil + jauge batterie sur dégradé bleu nuit, marges macOS standard. Générée par code (`Scripts/generate-icon.swift`, SwiftUI ImageRenderer) → toutes tailles dans `Assets.xcassets/AppIcon.appiconset` ; `ASSETCATALOG_COMPILER_APPICON_NAME` dans project.yml.

### Learned
- Les builds **Debug** de Xcode 26+ embarquent `ZendureMonitor.debug.dylib` : la re-signer aussi, sinon dyld refuse (Team ID mismatch). Pour installer un build local signé Dev ID, préférer un build **Release** stagé via ditto puis signé appex → Sparkle → app (jamais `--deep`, qui écrase les entitlements de l'appex).

### Installed
- Build Release signé installé dans /Applications (icône visible). Non releasé — proposer v1.3.1/v1.4.0.

## 2026-08-04 (v1.3.0 release, PR #9)

### Added
- Widget macOS (WidgetKit, small/medium) : production, batterie, maison, énergie du jour, mini-courbe. Extension sandboxée `fr.lauriat.ZendureMonitor.widget`, App Group `KFLACS69T9.fr.lauriat.ZendureMonitor`, snapshot JSON atomique (pattern MacInside). L'app publie à chaque poll + reload WidgetKit toutes les 2 min.
- Onglet Contrôle : acMode (charge secteur / injection), outputLimit, inputLimit via `POST /properties/write` (valeurs pré-remplies depuis le device, avertissement explicite). Format du POST validé contre le mock — jamais testé en écriture sur la vraie batterie.
- Export CSV (≤ 90 jours) depuis la carte Historique (NSSavePanel).
- release.sh : signature des .appex avant l'app, chacun avec ses entitlements ; app signée avec les siens (App Group).

### Learned
- macOS (Tahoe) protège les Group Containers par TCC : un process non entitlé voit un dossier vide et `touch` échoue en « Operation not permitted ». Vérification fiable = lecteur CLI signé Developer ID avec l'entitlement du groupe.

### Verified
- Notarisation acceptée (appex incluse), Gatekeeper OK, widget enregistré (`pluginkit -m` → fr.lauriat.ZendureMonitor.widget), snapshot lu avec données fraîches (1 030 W, 21 %). v1.3.0 installée dans /Applications.

## 2026-08-04 (v1.2.0 release, PR #7 + #8)

### Added
- Carte « Historique » : histogramme kWh/jour (14 jours affichés, 90 conservés puis purgés, clés UserDefaults `energyWh-<yyyy-MM-dd>`), total de la période, barre du jour en surbrillance. Composant `DailyBarChart` (Charts, style MacInside).
- v1.2.0 publiée : DMG notarisé (1,1 M), release GitHub, appcast `sparkle:version=3` — mise à jour servie aux installs 1.0.0/1.1.0.
- README : captures light/dark régénérées avec la carte Historique ; roadmap cochée.

### Verified
- PR #7 mergée, appcast en ligne (1.2.0), stapler OK, Gatekeeper « Notarized Developer ID », 1.2.0 officielle installée dans /Applications (≈1 kW en direct).

## 2026-08-04 (réglages onglets / i18n / thème, PR #6)

### Added
- Réglages découpés en 5 onglets : Appareil, Affichage, Général, Notifications, Distant (fenêtre bien plus compacte, 440 pt).
- Localisation FR/EN via String Catalog (`Sources/Localizable.xcstrings`, source fr, dev region fr — l'anglais est choisi automatiquement sur un système EN).
- Thème Auto/Sombre/Clair (onglet Affichage, `NSApp.appearance`).
- Captures d'écran light/dark dans `docs/` (rendu headless ImageRenderer, boutons du footer rognés — artefact hors-fenêtre), intégrées au README.

### Learned
- `NSApp` est nil dans le harness CLI → `_ = NSApplication.shared` avant de créer Monitor.
- Assignations dans `init` ne déclenchent pas les `didSet` des @Published — les settings ne sont pas réécrits au lancement.

## 2026-08-04 (options/alertes/distant, PR #5)

### Added
- Options d'affichage barre de menu : production W / batterie % / maison W (ou icône seule).
- Lancement au démarrage (SMAppService) dans Réglages → Général.
- Alerte batterie faible (UserNotifications, seuil 5–50 %, défaut 15 %).
- Compteur d'énergie solaire du jour (intégration des polls, persisté par jour en UserDefaults), affiché dans la carte Production.
- Détail par pack dans la carte Batterie : SOC, température (maxTemp 0.1 K → °C), puissance — inspiré de l'intégration HA.
- Hôte de secours optionnel (accès distant via VPN) : essayé quand l'adresse principale ne répond pas ; indicateur « via l'hôte de secours » dans le panneau ; section README « Remote access » (⚠️ jamais de port-forward du port 80, API sans auth).

### Installed
- Build Dev ID installé dans /Applications, vérifié en réel (1,0 kW, batterie 23 %). Release v1.2.0 non publiée (en attente du go).

## 2026-08-04 (v1.1.0 release, PR #4)

### Added
- v1.1.0 published: version bump (marketing 1.1.0, build 2), notarized DMG (1,0 M), GitHub release, appcast updated — first update actually served to 1.0.0 installs via Sparkle.
- Official 1.1.0 installed in /Applications (Gatekeeper: Notarized Developer ID), verified live at ~1 kW production.

## 2026-08-04 (graphs, PR #3)

### Added
- MacInside-style panel: MetricCard / SparklineChart (Swift Charts) / CircularGauge / LegendRow copied from MacInside for a shared design language.
- Three cards: solar production (big value + yellow sparkline + per-MPPT legend), battery (SOC ring gauge, charge/discharge, flow sparkline), home/grid flows (blue sparkline).
- Monitor: rolling histories (solar/home/batteryFlow, 180 samples) feeding the sparklines.

### Fixed / learned
- Dev builds (ad-hoc or freshly signed) get **silently denied local-network TCC** once the /Applications copy owns the grant — polls fail while curl works. Workaround: install dev builds to /Applications with the Developer ID signature (same bundle id + path → inherits the grant). Verified: localhost mock is not TCC-gated (good for UI testing), headless ImageRenderer harness renders MenuView without a device.
- First real daylight data confirmed (≈250 W at sunrise).

## 2026-08-04 (v1.0.0 release)

### Added
- Sparkle 2.9.1 auto-update: SPM dependency, `Updater.swift` (SPUStandardUpdaterController), "Mises à jour…" button in the panel, `SUFeedURL` → appcast.xml on main, `SUPublicEDKey` (new EdDSA key, keychain account "ZendureMonitor", backup in ~/.sparkle-keys/).
- `Scripts/release.sh` adapted from Templates/Scripts/release-full.sh (no custom DMG background): Developer ID + Hardened Runtime deepest-first signing, notarization (profile AppliMacVincentGithub), stapling, Sparkle EdDSA signing, appcast generation.
- Public GitHub repo `vincentlauriat/ZendureMonitor` (MIT license), full technical README in English.

### Changed
- Version bumped to 1.0.0.

### Decisions
- Git workflow: bootstrap commit on main, then feat/initial-release branch → PR → merge (no direct pushes to main).
- Appcast served from raw.githubusercontent.com main branch (same pattern as MarkdownViewer); DMG hosted as GitHub release asset.

## 2026-08-04 (bis)

### Fixed
- Menu bar label now shows "— W" next to the icon when unconfigured (Vincent couldn't spot the bare icon).
- Bonjour discovery found nothing: the SolarFlow 2400 Pro firmware advertises under `_http._tcp` (instance `Zendure-<model>-<sn>`), not `_zendure._tcp` as documented. Discovery now browses both types (filtering `_http` results on the "Zendure" name prefix); `NSBonjourServices` extended accordingly.

### Changed
- Device host pre-configured to `Zendure-solarFlow2400Pro-[SN-1].local`; app verified live against the real device (nested `properties` payload confirmed, battery 10%, 2 packs).

## 2026-08-04

### Added
- Initial project: SwiftUI menu bar app (xcodegen, macOS 14+, LSUIElement).
- Local zenSDK client: polls `GET http://<device>/properties/report`, tolerant parser (nested/flat payloads, mixed number types), smoke-tested via swiftc.
- Menu bar label with live solar production (W/kW); detail panel with battery SOC + charge/discharge flow, output to home, grid input, per-MPPT PV.
- Bonjour discovery of `_zendure._tcp` devices with hostname resolution.
- Settings window: host/IP, poll interval slider (2–60 s), network scan, connection test.
- Info.plist: NSLocalNetworkUsageDescription, NSBonjourServices, NSAllowsLocalNetworking.

### Decisions
- Integration path = local zenSDK REST API (official, port 80) rather than Zendure cloud API or MQTT: no credentials, no broker, works offline.
- `electricLevel` preferred over `socLevel` for SOC (average across packs), fallback kept.
- Debug builds signed ad hoc (`codesign -s -`) so the local-network privacy prompt behaves.

### Docs
- README.md, PLAN.md, TODOS.md, MEMORY.md, COMMANDS.md, .gitignore created.
