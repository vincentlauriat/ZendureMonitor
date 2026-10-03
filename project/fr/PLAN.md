# PLAN — Zendure Monitor

## Phase 14 — v2.3 « Deux SolarFlow » : multi-appareils de premier ordre (livrée : release v2.3.0 le 2026-10-03)

Déclencheur : Vincent a ajouté un second SolarFlow 2400 Pro (SN [SN-2], [IP])
à côté du premier (SN [SN-1], [IP]) ; l'app n'en voyait qu'un — architecture
mono-appareil par conception (un `deviceHost`, un `cloudDeviceKey`, un `state`).
Décisions de Vincent : **total + détail** (une installation agrégée partout, plus une
carte « Appareils ») ; **liste d'adresses préremplie par Bonjour** en local.

1. `DeviceState.combine` (pur, TDD) — puissances additionnées, packs concaténés, SOC =
   moyenne pondérée par nombre de packs (packs supposés de même capacité : chaque
   appareil a un pack type 500 + un type 350, aucun champ capacité dans `packData`),
   scalaires propres à un appareil (`acMode`, limites, socMin/Max, temp., rssi,
   BatVolt, autonomie, SN, voies PV) → nil. Invariant : 1 appareil ⇒ identique.
2. `Monitor` : `deviceHosts: [String]` (migration matérialisée depuis `deviceHost`),
   poll parallèle (TaskGroup), `fallbackHost` rattaché au 1er appareil, `devices:
   [DeviceReading]` par appareil, agrégat **marqué partiel** si un appareil manque,
   watchdog injoignable/anomalie par appareil, bascule auto Cloud seulement si TOUS
   échouent, sonde de retour sur n'importe quel hôte.
3. Mode Cloud : tous les appareils du deviceList agrégés (plus de filtre sur
   `cloudDeviceKey`), périmés → partiel.
4. Contrôle : cible un appareil précis (sn + hôte) via sélecteur — jamais l'agrégat.
5. UI : carte « Appareils » (panneau + tableau de bord), bandeau « partiel »,
   Réglages → Réseau en liste d'adresses ; Bonjour filtré sur `solarFlow`.
6. Vérif : tests, xcodebuild, rendu PNG des vues à 4 packs, essai réel ([IP] + [IP]).

## Phase 13 — v2.0 « Hélios 3D » : le soleil et la maison en vraie 3D (en cours)

Brief : « la grande nouveauté sera l'affichage 3D du soleil et de la localisation en
s'inspirant de l'extension Home Assistant ReikanYsora/helios ». Décisions validées avec
Vincent le 2026-08-10 : numéro **2.0** (plus grosse évolution visuelle depuis le début),
rendu **SceneKit** (vrai 3D natif, zéro dépendance — Helios lui-même est en 2.5D canvas,
on va plus loin : bâtiments extrudés, soleil = vraie lumière directionnelle, ombres
portées réelles, caméra orbitale).

### Briques existantes réutilisées telles quelles
- `SunCalc` (éphémérides NOAA : azimut/élévation à toute date, événements, crépuscules)
- `SolarGeometry` + `PanelArray` (champs de panneaux : puissance crête, azimut, inclinaison)
- `LocationFetcher` (lat/lon), `WeatherService` (Open-Meteo : couverture nuageuse)
- `Monitor` (données en direct : solaire W, maison W, SOC, réseau, `todayCurve`)
- `HistoryService`/collecteur (courbes des jours passés pour la timeline)

### Phase A — Socle SceneKit (MVP visible)
1. Fenêtre « Hélios » (`Window id "helios"`, WindowPolicy, bouton d'en-tête indigo
   `cube.transparent` dans le panneau).
2. `HeliosSceneView` : `NSViewRepresentable` sur `SCNView` — sol stylisé + anneau de
   boussole (N/S/E/O gradués), fond de ciel dégradé, caméra orbitale contrainte
   (pas de passage sous le sol), lumière ambiante + **lumière directionnelle = soleil**.
3. Arc du soleil du jour : polyline 3D échantillonnée sur `SunCalc` (pas de 10 min),
   sphère-soleil à la position courante, lumière directionnelle alignée dessus →
   les ombres bougent avec le vrai soleil.
4. La maison au centre (boîte extrudée placeholder) + les champs de panneaux de
   l'utilisateur en plans inclinés (azimut/inclinaison réels), colorés par incidence.

### Phase B — La localisation : le quartier en 3D (OSM)
1. `OverpassService` : emprises de bâtiments autour de lat/lon (rayon ~150 m,
   `way["building"](around:…)` sur l'API Overpass publique), hauteurs depuis les tags
   `height` / `building:levels` × 3 m (défaut 6 m).
2. Cache disque par localisation arrondie (Application Support) — un seul fetch,
   bouton « Recharger le quartier » ; sans réseau ou sans données : la maison seule,
   la scène reste utilisable.
3. `GeoProjection` (pure, testée) : projection locale en mètres autour du centre
   (équirectangulaire — suffisant à l'échelle d'un quartier), puis extrusion
   `SCNShape` des polygones ; le bâtiment le plus proche du centre = la maison,
   mise en évidence.
4. Ombres portées réelles (shadow mapping de la lumière directionnelle) — le cœur
   de l'effet Helios : voir l'ombre du voisin passer sur ses panneaux.

### Phase C — L'énergie dans la scène
1. Billes de flux animées (à la Helios) : panneaux → SolarFlow → maison / batterie /
   réseau, cadence liée aux watts en direct.
2. Production du jour le long de l'arc (ruban 3D depuis `todayCurve`).
3. HUD SwiftUI par-dessus la scène : W en direct, SOC, météo — la couverture
   nuageuse assombrit ciel et lumière.

### Phase D — Timeline et polish
1. Scrubber temporel ±48 h (comme Helios) : soleil, ombres, lumière et courbes
   suivent ; jours passés nourris par le collecteur/l'historique cloud.
2. Ciel dynamique (nuit/aube/jour/crépuscule selon l'élévation, étoiles la nuit),
   transitions douces.
3. Mode « mur » épuré (UI qui s'efface), réglages (rayon du quartier, hauteur par
   défaut des bâtiments, qualité des ombres).
4. Tests (GeoProjection, parseur Overpass, mapping hauteurs — purs), captures,
   README, landing, guide FR/EN.

### Risques identifiés
- **Overpass** : API publique parfois lente/limitée → cache agressif + dégradation
  propre (maison seule). Jamais bloquant au lancement.
- **Performance SceneKit** : plafonner à ~200 bâtiments, géométries fusionnées
  (`flattenedClone`), ombres en qualité réglable.
- **SceneKit vs RealityKit** : SceneKit reste le bon choix macOS 14 sans dépendance ;
  l'API est stable même si Apple pousse RealityKit à terme.

### Phase E — Fusion Soleil → SunRoad (validée par Vincent le 2026-08-10)
Un seul écran solaire : la scène 3D remplace le dôme céleste et le compas (retiré —
ses informations vivent mieux en 3D), le reste de la fenêtre Soleil migre dans un
**panneau latéral droit repliable** (~330 pt, ScrollView de MetricCards repliables) :
1. **Champs de panneaux** avec les sliders azimut/inclinaison — branchés sur la 3D,
   le panneau pivote dans la scène pendant le geste (PanelArrayRow/AngleSlider portés).
2. **Production** : l'histogramme 14 jours (DailyBarChart) + total du jour.
3. **Éphémérides**, **Lumière et crépuscules**, **Productible théorique**, **Météo** —
   cartes portées telles quelles depuis SunView.
4. **Point central exact** : mode « Définir ma maison » — clic sur un bâtiment de la
   scène (hit-testing SCNView, nœuds nommés) → son centroïde devient la position de
   référence (`sunroadHouseLat/Lon`, prioritaire sur les réglages) ; retour possible
   à la position des réglages.
5. La fenêtre Soleil disparaît : le bouton soleil orange ouvre SunRoad, le bouton
   cube est retiré (retour à cinq actions). `SunView.swift` et `SunCompassView.swift`
   supprimés ; `SkyDomeView.swift` conservé (héberge ArrayPalette/PanelGlyph/Cardinal).
   La configuration (position, ajout/suppression de champs) reste dans Réglages → Soleil.
Mise en page : scène plein cadre à gauche (HUD haut-gauche, timeline en bas de la
scène seulement), sidebar à droite masquable (chevron, persisté) — le mode mur masque
tout. Fenêtre 1400×980 : la scène garde ≥ 1000 pt de large.

### Découpage release
- v2.0 quand A + B + C + E sont livrées (la timeline D.1 est livrée) ; le reste de
  D peut glisser en 2.0.x. Chaque phase = une feature branch mergée derrière la
  précédente, testée en build local signé avant merge.

## Phase 10 — Mode Cloud, Smart CT, schéma de flux v2 (livrée en 1.10.0 le 2026-08-09)
Brief : « rajouter un mode cloud à l'application en conservant le mode API local » — protocole
repris du projet validé en réel `~/DevApps/Experimentations/ZendureCloud` (Cloud Key → deviceList
signé SHA1 → MQTT temps réel).

1. **Couche cloud portée** dans `Sources/Cloud/` (zéro dépendance externe) : `CloudKey`
   (jeton base64 → apiUrl + appKey, découpe au dernier point), `ZendureAPI`
   (`POST /api/ha/deviceList` signé SHA1 `C*dafwArEOXK`), `MQTTClient`/`MQTTPacket`
   (MQTT 3.1.1 maison sur Network.framework), `CloudDeviceState` (fusion des rapports
   partiels + conversions d'unités + mapping vers `DeviceState` local), `CloudService`
   (orchestration, reconnexion 15 s par re-login complet, getAll 60 s sur queue séparée
   — piège deadlock documenté), `KeychainHelper` (Cloud Key dans le trousseau,
   service `fr.lauriat.ZendureMonitor`, jamais UserDefaults).
2. **Adaptateur pull, mono-appareil** : la boucle de poll de `Monitor` est inchangée ;
   en mode cloud `refresh()` lit un instantané fusionné (`cloudSnapshot()`, périmé au-delà
   de 180 s → erreur) — lastError, watchdog, isStale, notifications et widget fonctionnent
   à l'identique. `maxDt` de l'accumulateur élargi à 180 s en cloud (rapports espacés).
   Multi-appareils du compte : Picker `cloudDeviceKey` (défaut : premier).
3. **Lecture seule en cloud (v1)** : `properties/write` MQTT jamais validé en réel →
   onglet Contrôle désactivé, garde `ZendureError.cloudReadOnly` dans `writeProperties`.
4. **Réglages** : Picker de source (API locale / Cloud Zendure) dans l'onglet Appareil,
   section Cloud (SecureField + test de clé + statut de phase + appareil suivi),
   hôte de secours masqué en cloud. Pas de changement ATS/entitlements (HTTPS + NWConnection).
5. **Tests portés** (`Tests/CloudTests.swift`) : Cloud Key, signature, paquets MQTT,
   fusion/conversions, mapping DeviceState — sources cloud pures ajoutées à la target de tests.
6. **`Scripts/cloud-probe.swift`** : sonde CLI qui dump tous les topics/clés MQTT du compte —
   pour vérifier si le Smart CT expose la consommation globale maison et le soutirage réseau.
7. Traductions EN + docs + build/tests verts.

## Phase 9 — Fenêtre Soleil v3 : orientations des panneaux + héros animé (en cours 2026-08-08)
Brief : « plus d'information et une interface incroyable avec des animations avec le soleil sur ses orientations. »

1. **Géométrie solaire** (`Sources/Shared/SolarGeometry.swift`, Foundation pur — compilé aussi dans le widget) :
   `PanelArray` (nom, Wc, azimut, inclinaison), store JSON avec migration douce de `sunPeakWatts`,
   cos d'incidence, facteur plan-des-panneaux (direct 85 % / diffus 15 %, se réduit exactement à
   sin(élévation) à plat), productible par champ, meilleure heure, énergie ciel clair du jour,
   masse d'air, longueur d'ombre. Convention d'azimut identique à `SunCalc` (0 = nord, 180 = sud).
2. **`SunCalc` étendu sans rupture** : course du jour échantillonnée (`track`), franchissements
   d'altitude génériques (crépuscules civil/nautique/astronomique, heure dorée), déclinaison et
   prochain solstice/équinoxe. Signatures existantes inchangées (`OutageWatchdog` en dépend).
3. **Deux visuels animés** : `SkyDomeView` (dôme céleste — ciel dégradé selon l'élévation, course
   réelle du jour + arcs des solstices, production mesurée, normales des panneaux avec anneaux
   d'incidence, soleil halo/rayons animés, étoiles la nuit) et `SunCompassView` (compas polaire —
   azimut × élévation, secteurs des champs qui s'allument selon l'incidence).
4. **`SunView` v3** : héros + compas + carte détaillée par orientation + éphémérides enrichies
   (crépuscules, heure dorée, delta de durée du jour, prochain solstice) + productible + météo.
5. **Réglages → Soleil** : éditeur multi-champs (nom, Wc, azimut avec libellé cardinal, inclinaison).
6. Tests (`SolarGeometryTests`, ajouts `SunCalcTests`) + `project.yml` (nouveau fichier partagé
   listé explicitement dans la cible de tests) + traductions EN + docs.

## Goal
macOS menu bar app displaying live solar production from the Zendure SolarFlow 2400 kit, fully local (zenSDK REST API).

## Phase 1 — MVP (done 2026-08-04)
1. Research integration path → chosen: local zenSDK REST API (`GET /properties/report`, port 80, mDNS `_zendure._tcp`). Cloud API/MQTT rejected (needs credentials, less reliable).
2. Scaffold xcodegen project — SwiftUI `MenuBarExtra`, `LSUIElement`, macOS 14+.
3. Device client: tolerant JSON parser (nested `properties` or flat, Int/Double/String numbers).
4. Polling loop (2–60 s, default 5 s), persisted in UserDefaults.
5. Bonjour discovery + settings window (host, interval, connection test).
6. Verify: xcodebuild ✅, parser smoke test ✅, app launched ✅.

## Phase 2 — Comfort (not started)
- Launch at login (SMAppService).
- Daily energy history + sparkline in the panel.
- Error badge in menu bar icon when device unreachable.

## Phase 8 — Alertes de panne (done 2026-08-07, v1.8.0)
Suite incident SolarFlow (défaut d'injection batterie pleine, puis device hors réseau, app muette) :
1. `OutageWatchdog` pure (Sources/Shared) + 8 tests — injoignable > N min, production nulle en plein jour. ✅
2. Notifications « SolarFlow injoignable » (défaut ON, 10 min réglable) et « Production solaire anormale » (défaut ON, 30 min, soleil > 20°). ✅
3. Icône barre de menu ⚠️ « hors ligne ». ✅
4. Release v1.8.0 (PR #17, DMG notarisé, appcast, installée). ✅
5. Reste (v1.9) : parser les champs d'état/erreur zenSDK — dump du payload réel au retour du device.

## Phase 7 — Release 1.7.0 + documentation + référencement (done 2026-08-06)
1. Merge PR #16 (vague 2) → release 1.7.0 : DMG notarisé, release GitHub, appcast Sparkle, installation /Applications. ✅
2. Fix build GitHub Pages (docs/.nojekyll — cassé depuis v1.6.0). ✅
3. Captures régénérées (harness ImageRenderer, UI vague 2 : Soleil+météo, widget large). ✅
4. Documentation complète : docs/guide/ FR+EN (10 pages/langue), README enrichi, wiki GitHub. ✅
5. Landing docs/index.html actualisée (features 1.7.0 + liens guide). ✅
6. lauriat.fr : carte en catégorie Domotique + llms.txt, déployé ; hub github.io rafraîchi. ✅

## Phase 4 — Features & écosystème (done 2026-08-04, v1.1.0 → v1.4.0)
- v1.1.0 : graphes style MacInside (sparklines, jauge circulaire).
- v1.2.0 : options barre de menu, login item, alerte SOC, énergie du jour, packs, hôte de secours, réglages en onglets, i18n FR/EN, thèmes, historique 14 j.
- v1.3.0 : widget macOS (App Group), onglet Contrôle (POST /properties/write), export CSV.
- v1.3.1 : icône d'app (générée par script).
- v1.4.0 : fenêtre Tableau de bord (schéma de flux animé + indicateurs complets), collecteur 24/7 sur [Mac-collecteur] (⚠️ TCC réseau local à débloquer), correctifs.
- Écosystème : repo public + releases Sparkle, carte + llms.txt sur lauriat.fr (20ᵉ outil), accès distant Tailscale ([Mac-collecteur] subnet router).

## Phase 5 — Pistes suivantes (backlog trié dans TODOS.md)
- Tests unitaires + CI GitHub Actions ; sélecteur de période ; widget large ; notifications supplémentaires ; stats ; 中文 ; cartes réordonnables.
- Optimisation HC/HP (v2.0) ; landing page GitHub Pages ; app iOS ; multi-appareils ; CO₂/€.

## Phase 3 — Release (done 2026-08-04)
- Scripts/release.sh from Templates/Scripts/release-full.sh (Developer ID + notarization profile AppliMacVincentGithub + Sparkle EdDSA, no custom DMG background).
- Sparkle 2.9.1 integrated (new key, account "ZendureMonitor").
- git init, public repo vincentlauriat/ZendureMonitor, branch feat/initial-release → PR → merge.
- v1.0.0: notarized DMG in release/, GitHub release, appcast.xml on main.

## Phase 6 — Dev des idées du TODOS (en cours 2026-08-05, PR #13)
**Vague 1 (cette session)** :
1. Fenêtre « Soleil » dédiée (le tableau de bord reste un tableau de bord) : scène Window "sun", bouton dans le footer du panneau, SunCard retirée du dashboard, politique Dock partagée (compteur). Module Soleil v2 : course du soleil + production superposées, productible théorique ciel clair (puissance crête paramétrable × sin(élévation)), rendement estimé.
2. Statistiques : pic de puissance du jour (persisté `peakW-<day>`), comparaison avec hier — sous l'histogramme (panneau + dashboard).
3. Sélecteur de période sur le graphe principal du panneau : 15 min / Jour / 14 j (courbe du jour en buckets 5 min persistés `solarCurve-<day>`).
4. Notifications optionnelles opt-in : batterie pleine, tirage réseau alors que le solaire produit, record de production battu.
5. Économies : € / CO₂ évités (prix kWh + facteur g/kWh paramétrables) dans les cartes du dashboard.
6. Tests (parser, SunCalc, Format → déplacé dans Sources/Shared) sans host app + workflow GitHub Actions build+test sur PR.

**Vague 2 (plus tard)** : widget large, 中文, cartes réordonnables, HC/HP (après déblocage collecteur), landing page, météo du module Soleil, iOS, multi-appareils.

## Phase 7 — Vague 2 du backlog (livrée 2026-08-06, PR #16 ouverte — CI verte, merge en attente)
1. **Widget large (systemLarge)** : `WidgetSnapshot.dailyEnergy` (14 j, champ optionnel rétro-compatible), histogramme en pur SwiftUI + en-tête solaire/batterie/maison + total. Bouton rafraîchir AppIntents reporté.
2. **Météo fenêtre Soleil** : `WeatherService` Open-Meteo (HTTPS, sans clé, cache 30 min) — état actuel, couverture nuageuse, ensoleillement prévu du jour ; affiché dans une carte Météo de SunView.
3. **Tests Monitor** : extraction `DailyAccumulator` pure (dt borné, rollover jour, buckets 5 min, pic, cumuls solar/stored/grid) + tests ; `Monitor.accumulateEnergy` devient adaptateur.
Reportés (validation Vincent) : optimiseur HC/HP (plan dédié — pilote la vraie batterie), 中文, cartes réordonnables.
