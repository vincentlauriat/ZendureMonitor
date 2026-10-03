# TODOS — Zendure Monitor

## v2.0 — Hélios 3D (plan : PLAN.md Phase 13)
- [x] Phase A — socle SceneKit : fenêtre Hélios, scène (sol, boussole, ciel), arc 3D du soleil + lumière directionnelle, maison placeholder + panneaux inclinés — branche feat/helios-scene, en test (2026-08-10)
- [x] Renommage Helios → SunRoad (fichiers, types, fenêtre, bouton, doc) (2026-08-10)
- [x] Phase B — quartier OSM : OverpassService + cache, GeoProjection testée, extrusion des bâtiments, ombres portées réelles, maison surlignée — validée par Vincent, caméra initiale remontée pour cadrer l'arc du soleil (2026-08-10)
- [x] Phase C — énergie : billes de flux animées (4 flux, paliers de watts), ruban de production sur l'arc, HUD énergie (W, SOC, nuages) (2026-08-10)
- [x] Phase D — timeline ±48 h, météo dans la scène (nuages → lumière/ciel), mode mur, doc/landing/guide/README (2026-08-10)
- [x] Phase E — fusion Soleil → SunRoad : sidebar (sliders 3D, éphémérides, productible, météo, histogramme), maison au clic, compas retiré, fenêtre Soleil supprimée (2026-08-10)
- [x] Release v2.0.0 (build 20) : SunRoad — merge, DMG notarisé, release GitHub, appcast, installée et vérifiée (2026-08-11)

- [x] Capture d'écran SunRoad (faite par Vincent) intégrée landing + guide FR/EN + README, mergée et poussée (2026-08-11)

## Next
- [x] Onglet Contrôle : réserve / charge max / injection du surplus + cible « Tous les appareils » (2026-10-03, mergé `0607492`, non poussé)
- [ ] Vincent : appliquer réserve 20 % + injection autorisée depuis l'onglet Contrôle
- [ ] Push de main + release (v2.3.1 ou v2.4) pour distribuer les nouveaux contrôles
- [ ] Observer un soir la décharge à deux appareils : quand l'un atteint sa réserve, l'autre prend-il le relais ? (décide de l'étape 3 « répartition par l'app »)
- [x] CI rouge depuis v2.2.0 diagnostiquée (Xcode 26.6 du runner vs 27.2 local, Double→CGFloat implicite) — PR #18 verte (2026-10-03)
- [x] PR #18 mergée, CI de main verte (2026-10-03)
- [x] Multi-appareils : le 2ᵉ SolarFlow ([IP]) n'était pas vu — agrégation total + détail, liste d'adresses, poll parallèle, totaux partiels, watchdog par appareil, contrôle ciblé, cloud agrégé ; 120 tests, vérifié en réel sur les deux appareils (2026-10-03, branche feat/multi-device)
- [ ] Vincent : regarder Réglages → Appareil (liste d'adresses) et le panneau avec la carte « Appareils » dans l'app installée
- [x] Mode Cloud à deux appareils vérifié en réel (SOC agrégé 73,5 % = moyenne des deux) (2026-10-03)
- [ ] Collecteur 24/7 : mono-hôte (`ZENDURE_HOST`) et inactif (`lastSample: null`) — le rendre multi-hôte ou le déprécier (PRD question 3)
- [ ] Vincent : ajouter le champ de panneaux du 2ᵉ système dans Réglages → Soleil (prévision SunRoad calibrée sur 1800 Wc seulement)
- [x] Alertes batterie faible/pleine par appareil (choix de Vincent), 4 tests (2026-10-03)
- [x] `feat/multi-device` mergé `--no-ff` sur main (non poussé) (2026-10-03)
- [x] `main` poussé (1030941) (2026-10-03)
- [x] Contrat Apple Developer accepté par Vincent (2026-10-03)
- [x] Release v2.3.0 (build 23) : multi-appareils — DMG notarisé, release GitHub, appcast poussé, installée depuis le DMG et vérifiée (2026-10-03)
- [ ] Piste : identifier les appareils par SN plutôt que par IP (le DHCP a déjà déplacé le CT) — redécouverte Bonjour par SN
- [ ] Piste : nommer les appareils localement (« Toit », « Garage ») au lieu du SN
- [x] `PRD.md` rédigé à la racine (périmètre, principes, exigences F-01…F-94, roadmap, risques) — fait référence pour les arbitrages de périmètre (2026-08-14)
- [ ] Vincent : arbitrer les questions ouvertes du PRD §14 — ~~(1) multi-appareils~~ tranché le 2026-10-03 (total + détail) ; (2) jusqu'où l'optimiseur v2.4 écrit-il seul sur la batterie (rupture avec la lecture seule par défaut) ? (3) déprécier le collecteur 24/7 ? (4) sur quel signal la localisation chinoise ? (2026-08-14)
- [x] Tableau de bord : diagramme de Sankey **validé visuellement** par Vincent (« c'est très bien ») sur les rendus côte à côte schéma/Sankey, thèmes sombre et clair (2026-08-13)
- [x] Sankey : mergé `--no-ff` sur main (`8d9dc08`) (2026-08-13)
- [x] Sankey : captures du tableau de bord refaites sur données réelles (schéma complet + carte Sankey recadrée, au même instant), légendes fr/en réécrites, README et guides à jour (2026-08-13)
- [x] Release v2.2.0 (build 22) : lecture Sankey du flux d'énergie — DMG notarisé, release GitHub, appcast poussé, installée depuis le DMG et vérifiée (2026-08-13)
- [x] Tableau de bord : seconde représentation des flux en diagramme de Sankey (largeur ∝ watts, bilan du hub explicite, soutirage non mesuré hachuré hors échelle), sélecteur persisté (2026-08-13, branche feat/sankey-energy-flow)
- [x] Release v2.1.0 (build 21) : courbes SunRoad + fix Historique + garde-fou CT — DMG notarisé, release GitHub, appcast poussé, installée/vérifiée (2026-08-11)
- [x] Vincent : corriger deviceHost → [IP-SolarFlow-1] dans Réglages — résolu : `deviceHosts = [.46, [IP]]` (2026-10-03) (le SolarFlow ; [IP] est le Smart CT depuis un changement DHCP — ctHost [IP] est correct)
- [x] Poll local : refuser le payload d'un Smart CT pris pour un SolarFlow (garde-fou signature dans ZendureParser + erreur notASolarFlow) (2026-08-11, releasé en 2.1.0)
- [x] SunRoad : conso refaite en courbe continue 24 h à la Helios (cercle horaire complet, piquets 15 min, badge ⌂ W au-dessus de la maison) — remplace les bâtons orange (2026-08-11, branche feat/sunroad-consumption-curve)
- [x] SunRoad : ruban de consommation maison le long de l'arc (à la Helios) — homeCurve 5 min dans DailyAccumulator, CT+injection sinon injection seule, bâtons orange en retrait, échelle commune avec la production (2026-08-11, branche feat/sunroad-consumption-ribbon)
- [x] Historique : SmartMeter 3CT toujours affiché sans données — 3e cause : tdengine renvoie la structure solarFlow complète toute à zéro ; fix `hasEnergySignal` (valeur non nulle hors clés méta) dans HistoryService, cache de zéros purgé (2026-08-11, branche fix/smartmeter-history-zero-fields)
- [ ] v2.2 : lettres cardinales E/S en miroir selon l'angle caméra (SCNText à réorienter — billboard ou double face), noms de rues, végétation/plans d'eau OSM, réglage du rayon du quartier, étoiles la nuit, compas en couche optionnelle si manque, dégraisser SkyDomeView (garder ArrayPalette/PanelGlyph/Cardinal)

## Done
- [x] Fix reprise après veille (retry HTTP deviceList, timeout PINGRESP, hook didWake) + checkbox carte Débogage dans l'Historique — test capot validé par Vincent, mergé sur main (1aba549) ; release 1.12.1 à décider (2026-08-10)
- [x] Landing + guide FR/EN mis à jour pour la 1.12 (carte History window, pages historique.md/history.md, sommaires et navigation) — mergé sur main, Pages redéployé (2026-08-10)
- [x] Release v1.12.0 (build 19) : fenêtre Historique — merge, DMG notarisé, release GitHub, appcast (2026-08-10)
- [x] Métriques par source dans l'Historique (sélecteur par carte d'appareil, limité aux champs réels, choix mémorisé) — retour de test validé (2026-08-10)
- [x] Module Historique porté depuis ZendureCloud (fenêtre barres kWh 7/30/90/365 j, API privée app Zendure, cache disque, 12 tests) — validé en test puis mergé (2026-08-10)
- [x] Release v1.11.1 (build 18) : patch diagnostic MQTT cloud — merge, DMG notarisé, release GitHub, appcast, installée et vérifiée (2026-08-10)
- [x] Patch diagnostic MQTT cloud (SUBACK parsé, détection takeover, filtre deviceList) (2026-08-10)
- [x] Landing + guide FR/EN mis à jour pour la 1.11 (bascule auto, cartes repliables, carte Conso maison documentée) — mergé sur main, Pages déployé (2026-08-10)
- [x] Release v1.11.0 (build 17) : bascule auto + cartes repliables — merge, DMG notarisé, release GitHub, appcast, installée et vérifiée (2026-08-10)
- [x] Cartes du panneau repliables (clic en-tête, résumé compact, état persisté) + toggles de visibilité dans Réglages → Affichage (2026-08-10)
- [x] Option « Basculer automatiquement » local ⇄ cloud (2 échecs locaux → Cloud si clé ; sonde 60 s → retour local) (2026-08-10)
- [x] Release v1.10.4 (build 16) : état Smart CT injoignable — merge, DMG notarisé, release GitHub, appcast, installée et vérifiée (2026-08-10)
- [x] UI : trois états du Smart CT (mesuré / configuré-injoignable / non configuré) dans la carte Consommation maison et la légende du dashboard (2026-08-10)
- [x] Release v1.10.3 (build 15) : carte Consommation maison — merge, DMG notarisé, release GitHub, appcast, installée et vérifiée (2026-08-09)
- [x] Carte « Consommation maison » dans le panneau de la barre de menus (total CT + détail par source, fallback sans CT) + calcul centralisé dans EnergyMath (2026-08-09)
- [x] Choose integration path: local zenSDK REST API (2026-08-04)
- [x] Scaffold xcodegen project (MenuBarExtra, LSUIElement) (2026-08-04)
- [x] Parser for /properties/report (nested + flat, smoke-tested) (2026-08-04)
- [x] Polling loop + UserDefaults persistence (2026-08-04)
- [x] Bonjour discovery (_zendure._tcp) + settings window (2026-08-04)
- [x] Debug build passes, app launched in menu bar (2026-08-04)

- [x] Fix discovery: firmware advertises `_http._tcp`, not `_zendure._tcp` — browse both (2026-08-04)
- [x] Validate real payload from the SolarFlow 2400 Pro (nested `properties`, fields match parser) (2026-08-04)
- [x] Host pre-configured, app connected live (2026-08-04)

- [x] git init + public GitHub repo (vincentlauriat/ZendureMonitor) + feature branch workflow (2026-08-04)
- [x] Sparkle 2 auto-update integrated (new EdDSA key, account "ZendureMonitor") (2026-08-04)
- [x] Release pipeline Scripts/release.sh (DMG signed + notarized + Sparkle-signed) (2026-08-04)
- [x] Public README with full technical explanation (EN) + MIT license (2026-08-04)

- [x] Check display in daylight (≈250 W at sunrise) (2026-08-04)
- [x] Sparklines + battery gauge, MacInside style (PR #3) (2026-08-04)

- [x] Release v1.1.0 (graphs) — DMG notarisé, release GitHub, appcast à jour (2026-08-04)

- [x] Menu bar display options (solar/battery/home toggles) (PR #5, 2026-08-04)
- [x] Launch at login (SMAppService) (PR #5, 2026-08-04)
- [x] Low-battery (SOC) alert, threshold 5–50 % (PR #5, 2026-08-04)
- [x] Today's energy counter (persisted per day) (PR #5, 2026-08-04)
- [x] Per-pack SOC/temp/power in battery card (PR #5, 2026-08-04)
- [x] Fallback host for VPN remote access + README section (PR #5, 2026-08-04)

- [x] Réglages en onglets (5 tabs) (PR #6, 2026-08-04)
- [x] Localisation FR/EN (String Catalog) (PR #6, 2026-08-04)
- [x] Thème Auto/Sombre/Clair (PR #6, 2026-08-04)
- [x] Captures d'écran light/dark dans le README (PR #6, 2026-08-04)

- [x] Multi-day production history (carte Historique, 14 j / 90 j) (PR #7, 2026-08-04)
- [x] Release v1.2.0 publiée (DMG notarisé + appcast Sparkle) (2026-08-04)

- [x] Widget macOS small/medium (App Group + snapshot JSON) (PR #9, 2026-08-04)
- [x] Onglet Contrôle acMode/outputLimit/inputLimit (PR #9, 2026-08-04)
- [x] Export CSV de l'historique (PR #9, 2026-08-04)
- [x] Release v1.3.0 publiée (2026-08-04)

- [x] Icône d'app (PR #10, 2026-08-04)

- [x] Release v1.3.1 publiée (icône) (2026-08-04)

- [x] Vincent : widget ajouté et validé (2026-08-04)
- [x] Vincent : onglet Contrôle validé sur la vraie batterie (2026-08-04)
- [x] Carte Zendure Monitor sur lauriat.fr (+ llms.txt, compteurs 19→20), déployé (2026-08-04)

- [x] VPN accès distant opérationnel : Tailscale sur [Mac-collecteur] (subnet router 192.168.x.0/24, route approuvée) + sur le MacBook, hôte de secours [IP-SolarFlow-1] configuré dans l'app (2026-08-04)

## Next
- [ ] Utilisateur 2 SolarFlow : attendre son retour sur la 1.11.1 (nouveau message takeover ? boucle toutes les ~15-30 s ? Home Assistant/ioBroker/autre Mac avec la même Cloud Key ? le Cloud marchait-il en 1.10.x ?) (2026-08-10)
- [x] Vincent : premier test réel en déplacement — validé le matin du 2026-08-06 (« ça a fonctionné très bien » via Tailscale)
- [ ] **[Mac-collecteur] : empêcher la veille** — confirmé endormi le 2026-08-06 après-midi (Tailscale `rx 0` → plus d'accès distant du tout) : sur place, `sudo pmset -a sleep 0 displaysleep 10` ou Réglages → Économie d'énergie
- [x] PR #16 mergée + release **1.7.0** publiée (DMG notarisé, release GitHub, appcast Sparkle, installée dans /Applications avec lsregister) (2026-08-06)
- [x] Build GitHub Pages réparé (docs/.nojekyll — les builds échouaient depuis v1.6.0) (2026-08-06)
- [x] Carte lauriat.fr déplacée en catégorie **Domotique** + llms.txt 1.7.0, déployé ; carte hub vincentlauriat.github.io rafraîchie (2026-08-06)
- [x] Documentation complète : guide utilisateur FR+EN dans docs/guide/ + README enrichi + wiki GitHub, nouvelles captures (2026-08-06)
- [ ] Au retour à la maison : tester la vague 2 en réel (polling local, widget large, météo Soleil, fenêtre Soleil sans scroll) — si réseau local KO : `lsregister -f` + relance (voir MEMORY.md)
- [ ] Claude : proposer le plan de l'optimiseur HC/HP (pilote la vraie batterie → validation Vincent avant tout code)
- [ ] **Incident 2026-08-07 : SolarFlow en défaut (pas d'injection, batterie pleine) ET hors réseau (ARP incomplete, ping/mDNS morts)** — action Vincent sur place : LED/app Zendure officielle (Bluetooth), redémarrage du hub
- [x] **Alertes de panne (a, b, d)** : notification « appareil injoignable > N min » (défaut ON, 10 min réglable), notification « production nulle en plein jour » (défaut ON, 30 min, soleil > 20°), icône barre de menu ⚠️ « hors ligne » — `OutageWatchdog` pure + 8 tests, 40/40 verts, FR/EN (PR #17 mergée, **release v1.8.0 publiée + installée**, 2026-08-07)
- [ ] **(c) Parser les champs d'état/erreur zenSDK** — dump du payload réel `GET /properties/report` à faire au retour du device, puis affichage carte Appareil + notification défaut
- [x] **Fenêtre Soleil v3** (branche `feat/sun-panel-orientations`, 2026-08-08) : orientations multiples des panneaux (azimut + inclinaison par champ, migration de `sunPeakWatts`), dôme céleste animé (course réelle du jour, solstices, production posée sur l'axe des azimuts, marqueurs d'orientation), compas solaire avec contours d'iso-incidence, détail par champ (productible, incidence, meilleure heure, potentiel du jour), crépuscules + heures dorées + prochain solstice, transmittance atmosphérique dans le modèle de productible — 59 tests verts
- [x] Régénérer `docs/guide/images/settings-sun.png` (2026-08-08) : section extraite dans `PanelArraysSection`, `SunSettingsTab` rendue interne, onglet capturé par le harnais — au passage, correction de la mise en page éclatée dans le `Form` groupé et de la perte de `sunPeakWatts` à la suppression du dernier champ
- [x] Fenêtre Soleil sur un seul écran + réglage des orientations sur place (2026-08-08) : trois bandes, 1400×980, contenu mesuré à 927 pt, curseurs azimut/inclinaison par champ
- [x] Vincent : curseur d'inclinaison **validé en réel** (2026-08-09, sur un build Debug donc le cas pessimiste) — la mesure de 60 ms/cran du harnais était bien une borne haute due au layout forcé, pas le coût d'un vrai glissement
- [x] Branche `feat/sun-panel-orientations` poussée puis mergée `--no-ff` sur `main` et poussée (`91575b5`, 2026-08-08) — landing, README et index du guide mis à jour dans le même lot. **Pas de release cutée**, le tag reste à arbitrer.
- [x] **Release 1.9.0 publiée** (2026-08-09) : bump 1.8.0 → 1.9.0 / build 10 → 11, DMG notarisé et agrafé vérifié indépendamment (`spctl` → `accepted, source=Notarized Developer ID`), release GitHub `v1.9.0` créée **avant** la publication de l'appcast (sinon les clients Sparkle tombent sur une URL de téléchargement en 404), appcast relu en ligne
- [x] ~~Si le glissement stutter : découper les couches de `SkyDomeView`, ou ne persister qu'au relâchement~~ — sans objet, validé fluide
- [x] 1.9.0 installée dans `/Applications` (2026-08-09) + réparation `lsregister -f` et relance du Dock, sur accord explicite de Vincent — enregistrement vérifié en `version: 11.0`, `spctl` toujours `Notarized Developer ID`
- [x] Ménage du dépôt (2026-08-09) : plus que `main` en local et sur GitHub (5 + 5 branches supprimées), après vérification qu'aucune n'était non mergée ; 11 tags intacts
- [ ] Vider la copie 1.6.0 de l'app restée dans la corbeille iCloud (`~/Library/Mobile Documents/.Trash/`) : elle reste un candidat au lancement dans la base Launch Services
- [ ] Revérifier l'autorisation « réseau local » de la 1.9.0 quand le SolarFlow sera revenu sur le réseau — non testable de bout en bout tant qu'aucun appareil Zendure ne s'annonce en Bonjour
- [ ] Exercer le bouton « Ajouter un champ » et les curseurs de l'éditeur (dessinés par SwiftUI sans vue AppKit pilotable : hors de portée du harnais, à couvrir en test manuel ou via un test d'UI)

## Backlog (proposé le 2026-08-04, en attente d'arbitrage Vincent)

### Corrections / robustesse
- [x] Collecteur 24/7 (Scripts/collector, LaunchAgent [Mac-collecteur], API JSON) + intégration app (v1.4.0) — ⚠️ reste le déblocage TCC réseau local sur [Mac-collecteur] (action Vincent)
- [x] Anti double-envoi + confirmation 0 W sur Contrôle (v1.4.0)
- [x] Ligne du zéro sur la sparkline batterie (v1.4.0)
- [x] Message « Aucun appareil trouvé » (v1.4.0)
- [x] Tests unitaires (parser, SunCalc, Format — 9 tests) + GitHub Actions build+test sur chaque PR (2026-08-05)
- [x] Widget : données périmées grisées + ancienneté (v1.4.0)
- [ ] Vincent : autoriser l'accès « réseau local » de python3 sur [Mac-collecteur] (prompt à l'écran ou Réglages → Confidentialité → Réseau local) pour débloquer le collecteur

### Améliorations UX
- [x] Fenêtre « Tableau de bord » complète avec schéma de flux animé + tous les indicateurs (température, RSSI, tension, autonomie, limites, plage SOC) — demande Vincent, v1.4.0
- [x] Schéma de flux réaliste : décomposition solaire/batterie/réseau → maison, liens animés uniquement quand le flux existe, watts sur chaque lien (2026-08-05)
- [x] Bouton « Ouvrir le tableau de bord » proéminent dans le panneau + icône Dock/Cmd-Tab quand la fenêtre est ouverte (2026-08-05)
- [x] Bandeau de détection du blocage TCC « réseau local » avec bouton vers les réglages + réessayer — demande Vincent (2026-08-05)
- [x] Schéma de flux v3 : SolarFlow hub central, batteries en satellite, + prise hors-réseau (`gridOffPower`) — demande Vincent (2026-08-05)
- [x] Module Soleil : éphémérides NOAA locales (SunCard + réglage lat/lon) — demande Vincent (2026-08-05)
- [x] Double-clic sur les graphiques du panneau → tableau de bord — demande Vincent (2026-08-05)
- [x] Bouton « Utiliser la position de ce Mac » (CoreLocation one-shot) pour le module Soleil — demande Vincent (2026-08-05)
- [x] Fix bouton localisation qui tournait dans le vide (timeout + pré-contrôle service + messages distincts) (2026-08-05)
- [x] Section « Autorisations » dans les Réglages + avertissements au démarrage (réseau local, localisation, notifications) — demande Vincent (2026-08-05)
- [x] Module Soleil v2 : fenêtre « Soleil » dédiée (hors dashboard), course du soleil + production superposées, productible théorique (Wc × sin(élévation)), rendement estimé (2026-08-05)
- [x] Météo locale dans la fenêtre Soleil : Open-Meteo, couverture nuageuse, ensoleillement prévu, productible ajusté nuages (2026-08-06, PR #16)
- [x] Vincent : débloquer le grant réseau local sur son Mac — résolu le 2026-08-09 : redémarrage du Mac + suppression de la cause d'invalidation (build Debug adhoc lancé depuis DerivedData, voir « Reprise après redémarrage »)
- [x] Sélecteur de période sur le graphe principal : 15 min / Jour / 14 j (2026-08-05)
- [x] Widget large (systemLarge) avec l'histogramme 14 jours (2026-08-06, PR #16) — reste : bouton rafraîchir AppIntents
- [x] Notifications optionnelles : batterie pleine, tirage réseau inattendu, record du jour (2026-08-05)
- [x] Statistiques : pic de puissance du jour + comparaison avec hier sous l'histogramme (record déjà présent) (2026-08-05)
- [ ] Localisation 中文 (le site est trilingue, le catalogue de chaînes rend ça mécanique). Effort S.
- [ ] Ordre des cartes personnalisable par glisser-déposer (pattern MacInside). Effort M.

### Évolutions
- [ ] **Optimisation heures creuses/pleines** : programmateur local (charge secteur la nuit HC, injection HP) via `POST /properties/write` + estimation d'économies €. Effort L, très forte valeur si tarif HC/HP ou Tempo. Dépend du collecteur [Mac-collecteur] pour être vraiment utile.
- [x] Landing page GitHub Pages — existait déjà, actualisée 1.7.0 + build Pages réparé (2026-08-06). Reste éventuellement : page dédiée `outils/zenduremonitor/` sur lauriat.fr (la carte pointe vers la landing GitHub Pages).
- [ ] App iOS compagnon (SwiftUI largement partageable, accès via Tailscale iOS). Effort L.
- [ ] Support multi-appareils Zendure (agrégation de plusieurs SolarFlow). Effort M/L — inutile tant qu'il n'y a qu'un kit.
- [x] Estimation CO₂ évité / € économisés (tarif kWh + facteur g/kWh paramétrables) (2026-08-05)

### Corrections revue de code (2026-08-06)
- [x] Debounce restart polling (frappe hôte / slider intervalle) (2026-08-06)
- [x] Hôte de secours mémorisé (retest du principal toutes les 2 min au lieu de chaque poll) (2026-08-06)
- [x] Données conservées + grisées hors ligne au lieu de « Pas de données » (2026-08-06)
- [x] Clé de jour en fuseau local (était UTC via ISO8601) (2026-08-06)
- [x] Zéro warning : concurrence PermissionsStatus + CFBundleVersion widget synchronisé (2026-08-06)
- [x] Répartition solaire du jour (direct/stocké + cumul réseau) dans la carte Flux — le vrai taux d'autoconsommation est impossible sans compteur maison (2026-08-06)
- [x] Tests unitaires sur Monitor : `DailyAccumulator` pure extraite (dt borné, rollover, buckets, pic, fusion collecteur) + 8 tests — 28/28 verts (2026-08-06, PR #16)
- [x] Release v1.6.0 publiée : DMG notarisé + release GitHub + appcast + README, installée dans /Applications (2026-08-06)

### Ergonomie (2026-08-05)
- [x] Panneau style Juicy : en-tête avec boutons-icônes, suppression de la rangée de boutons du bas — demande Vincent
- [x] Réglages réorganisés : onglet Soleil dédié, Rafraîchissement dans Appareil, Général allégé — demande Vincent
- [x] Docs + captures régénérées (panel light/dark, dashboard, sun) via harness ImageRenderer, README + landing page à jour, PR #13 mergée (2026-08-05)
- [x] Release v1.5.0 publiée : DMG notarisé + release GitHub + appcast + version installée dans /Applications (2026-08-05)

### Mode Cloud (2026-08-09, branche feat/cloud-mode)
- [x] Couche cloud portée de ZendureCloud dans Sources/Cloud/ (CloudKey, ZendureAPI signé SHA1, MQTTClient maison, CloudDeviceState fusion + conversions, CloudService, KeychainHelper) (2026-08-09)
- [x] Monitor : sélecteur Local/Cloud persisté, adaptateur pull (cloudSnapshot, périmé > 180 s), maxDt élargi en cloud, garde lecture seule sur writeProperties (2026-08-09)
- [x] Réglages : Picker de source, section Cloud (SecureField + test de clé + statut + appareil suivi), Contrôle désactivé en cloud, hôte de secours masqué (2026-08-09)
- [x] 20 tests cloud portés (80/80 verts) + 33 chaînes FR→EN (2026-08-09)
- [x] Scripts/cloud-probe.swift : sonde des topics/clés MQTT du compte (question conso maison / soutirage réseau via Smart CT) (2026-08-09)
- [x] Mode Cloud testé en réel par Vincent : compte EU connecté, « Solar One » (SolarFlow 2400 Pro) en flux MQTT temps réel (2026-08-09)
- [x] Sonde cloud lancée en réel : pas de Smart CT sur le compte, aucune clé conso maison / soutirage réseau dans le flux MQTT — indisponible côté cloud sans appairer un Smart 3CT (2026-08-09)
- [ ] Si un Smart 3CT est appairé un jour : refaire la sonde puis cartes « Consommation maison » et « Soutirage réseau ». Effort M.
- [x] Le SolarFlow est revenu sur le LAN ([IP-SolarFlow-1]) : mode local re-testé et fonctionnel avec la 1.10.0 installée (2026-08-09 soir)
- [ ] properties/write via MQTT (contrôle en mode Cloud) — à valider prudemment en réel d'abord. Effort M.

### Schéma de flux d'énergie v2 (2026-08-09, branche feat/cloud-mode)
- [x] Losange aligné (batteries pile sous le hub), halos animés cohérents avec la fenêtre Soleil, pastilles SOC par pack (2026-08-09)
- [x] Arc « non mesuré » Réseau → Maison + note explicative (pas de Smart CT : conso maison totale inconnue) (2026-08-09)
- [x] Vérifié en rendu (harnais ImageRenderer, light/dark × 2 scénarios) (2026-08-09)

### Smart CT (2026-08-09, branche feat/cloud-mode)
- [x] Sonde renforcée (wildcards, 180 s, app quittée) : le CT ne publie pas sur le broker du compte HA et n'est pas dans deviceList — mais il répond en LOCAL (Bonjour _zendure._tcp + GET /properties/report) (2026-08-09)
- [x] SmartCT.swift (CTReport + parser testé sur payload réel), poll best-effort dans Monitor (les deux modes), réglage ctHost + détection Bonjour + test (2026-08-09)
- [x] Schéma de flux : arc Réseau → Maison mesuré (orange animé) + consommation totale maison quand le CT répond ; ctHost préconfiguré chez Vincent (2026-08-09)
- [ ] Historiser le soutirage réseau mesuré par le CT (cumul jour, carte dédiée) — comme energyTodayWh. Effort M.
- [x] Pied du panneau barre de menu : mode de connexion (local primaire / local secondaire / cloud) + pastille d'état (2026-08-09)
- [x] Réglages réorganisés : onglet Réseau (Smart CT + secours + collecteur), onglet Appareil allégé, textes d'aide compactés (2026-08-09)

### Release 1.10.0 (2026-08-09)
- [x] Bump 1.10.0 / build 12, notes de release, README + landing + guide (page Mode Cloud FR/EN) (2026-08-09)
- [x] Merge --no-ff sur main (c321637) + push (2026-08-09)
- [x] DMG notarisé (Accepted, agrafé, vérifié indépendamment : spctl Notarized Developer ID + codesign) + release GitHub v1.10.0 + appcast publié après la release (asset vérifié HTTP 200) (2026-08-09)
- [x] Captures panel light/dark + dashboard régénérées (harnais NSHostingView, fond opaque contre la vibrancy, données synthétiques 1.10 : pied de connexion, arc Smart CT mesuré, conso totale maison) et mergées sur main (bca52fc) (2026-08-09)

- [ ] Mode cloud : mapper `outputPower` du topic `properties/energy` (~3 s) sur outputHomePower pour un flux maison plus réactif que les reports (~5 s) — question de Vincent du 2026-08-09. Effort S.

### Reprise après redémarrage du Mac (2026-08-09, incident TCC réseau local)
- [x] Vincent : redémarrer le Mac (fait avant la session du 2026-08-09 soir)
- [x] Mode local revalidé (2026-08-09 soir) : cause résiduelle identifiée — une instance **Debug adhoc lancée depuis DerivedData** tournait à la place de l'app installée (chaque rebuild adhoc change la signature → macOS invalide le grant TCC réseau local ; le cloud, sortant Internet, n'est pas affecté). Correction : instances quittées, **1.10.0 installée dans /Applications** (DMG notarisé, spctl accepted), lsregister -f + killall Dock, copies fantômes désenregistrées de Launch Services (build/, DerivedData, corbeille iCloud) et builds purgés. Poll local vérifié : widget-snapshot.json réécrit avec données fraîches du SolarFlow.
- [x] Cuter la v1.10.1 avec le fix découverte Bonjour → IP (13f2257) — fait le 2026-08-09 nuit : DMG notarisé + agrafé + Sparkle, release GitHub v1.10.1, appcast poussé après vérification de l'asset (HTTP 200), installée dans /Applications, poll local vérifié
- [x] Merger `fix/energy-flow-no-crossing` (f6594e6, schéma planaire sans croisement — demande Vincent du 2026-08-09 soir) sur main (d72746f) et l'embarquer dans la v1.10.1 — fait
- [x] Régénérer la capture `docs/dashboard.png` — fait le 2026-08-09 nuit (X symétrique + Smart CT mesuré, harnais reconstruit, mergée dae8967)
- [x] Merger `feat/energy-flow-mirror-layout` (8e33fd3, X symétrique) et releaser — fait : v1.10.2 (build 14) publiée le 2026-08-09 nuit, installée et vérifiée
- [ ] v1.12 : mapper `outputPower` (properties/energy, ~3 s) sur le flux maison en mode cloud
