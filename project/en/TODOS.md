# TODOS — Zendure Monitor

## v2.0 — Hélios 3D (plan: PLAN.md Phase 13)
- [x] Phase A — SceneKit foundation: Hélios window, scene (ground, compass, sky), 3D sun arc + directional light, placeholder house + tilted panels — branch feat/helios-scene, in testing (2026-08-10)
- [x] Rename Helios → SunRoad (files, types, window, button, docs) (2026-08-10)
- [x] Phase B — OSM neighborhood: OverpassService + cache, tested GeoProjection, building extrusion, real cast shadows, highlighted house — validated by Vincent, initial camera raised to frame the sun arc (2026-08-10)
- [x] Phase C — energy: animated flow beads (4 flows, watt levels), production ribbon on the arc, energy HUD (W, SOC, clouds) (2026-08-10)
- [x] Phase D — ±48 h timeline, weather in the scene (clouds → light/sky), wall mode, docs/landing/guide/README (2026-08-10)
- [x] Phase E — Soleil → SunRoad merge: sidebar (3D sliders, ephemerides, yield, weather, histogram), house on click, compass removed, Soleil window deleted (2026-08-10)
- [x] Release v2.0.0 (build 20): SunRoad — merge, notarized DMG, GitHub release, appcast, installed and verified (2026-08-11)

- [x] SunRoad screenshot (taken by Vincent) integrated into landing + FR/EN guide + README, merged and pushed (2026-08-11)

## Next
- [x] Control tab: reserve / max charge / surplus feed-in + "Tous les appareils" target (2026-10-03, merged `0607492`, not pushed)
- [ ] Vincent: apply 20% reserve + feed-in allowed from the Control tab
- [ ] Push main + release (v2.3.1 or v2.4) to distribute the new controls
- [ ] Observe a two-device discharge one evening: when one reaches its reserve, does the other take over? (decides on step 3 "split by the app")
- [x] Red CI since v2.2.0 diagnosed (runner's Xcode 26.6 vs local 27.2, implicit Double→CGFloat) — PR #18 green (2026-10-03)
- [x] PR #18 merged, main's CI green (2026-10-03)
- [x] Multi-device: the 2nd SolarFlow ([IP]) was not seen — total + detail aggregation, address list, parallel poll, partial totals, per-device watchdog, targeted control, aggregated cloud; 120 tests, verified live on both devices (2026-10-03, branch feat/multi-device)
- [ ] Vincent: look at Settings → Appareil (address list) and the panel with the "Appareils" card in the installed app
- [x] Cloud mode with two devices verified live (aggregated SOC 73.5% = average of the two) (2026-10-03)
- [ ] 24/7 collector: single-host (`ZENDURE_HOST`) and inactive (`lastSample: null`) — make it multi-host or deprecate it (PRD question 3)
- [ ] Vincent: add the 2nd system's panel array in Settings → Soleil (SunRoad forecast calibrated on 1800 Wp only)
- [x] Low/full battery alerts per device (Vincent's choice), 4 tests (2026-10-03)
- [x] `feat/multi-device` merged `--no-ff` on main (not pushed) (2026-10-03)
- [x] `main` pushed (1030941) (2026-10-03)
- [x] Apple Developer agreement accepted by Vincent (2026-10-03)
- [x] Release v2.3.0 (build 23): multi-device — notarized DMG, GitHub release, appcast pushed, installed from the DMG and verified (2026-10-03)
- [ ] Idea: identify devices by SN rather than by IP (DHCP already moved the CT) — Bonjour rediscovery by SN
- [ ] Idea: name devices locally ("Toit", "Garage") instead of the SN
- [x] `PRD.md` written at the root (scope, principles, requirements F-01…F-94, roadmap, risks) — reference for scope arbitration (2026-08-14)
- [ ] Vincent: arbitrate the open questions of PRD §14 — ~~(1) multi-device~~ settled on 2026-10-03 (total + detail); (2) how far may the v2.4 optimizer write to the battery on its own (break with read-only by default)? (3) deprecate the 24/7 collector? (4) on what signal for the Chinese localization? (2026-08-14)
- [x] Dashboard: Sankey diagram **visually validated** by Vincent ("it's very good") on side-by-side renders diagram/Sankey, dark and light themes (2026-08-13)
- [x] Sankey: merged `--no-ff` on main (`8d9dc08`) (2026-08-13)
- [x] Sankey: dashboard captures redone on real data (full diagram + cropped Sankey card, at the same instant), fr/en legends rewritten, README and guides up to date (2026-08-13)
- [x] Release v2.2.0 (build 22): Sankey reading of the energy flow — notarized DMG, GitHub release, appcast pushed, installed from the DMG and verified (2026-08-13)
- [x] Dashboard: second representation of the flows as a Sankey diagram (width ∝ watts, explicit hub balance, unmeasured draw hatched off-scale), persisted selector (2026-08-13, branch feat/sankey-energy-flow)
- [x] Release v2.1.0 (build 21): SunRoad curves + History fix + CT safeguard — notarized DMG, GitHub release, appcast pushed, installed/verified (2026-08-11)
- [x] Vincent: fix deviceHost → [IP-SolarFlow-1] in Settings — resolved: `deviceHosts = [.46, [IP]]` (2026-10-03) (the SolarFlow; [IP] has been the Smart CT since a DHCP change — ctHost [IP] is correct)
- [x] Local poll: reject the payload of a Smart CT mistaken for a SolarFlow (signature safeguard in ZendureParser + notASolarFlow error) (2026-08-11, released in 2.1.0)
- [x] SunRoad: consumption redone as a continuous 24 h curve à la Helios (full hourly circle, 15 min stakes, ⌂ W badge above the house) — replaces the orange sticks (2026-08-11, branch feat/sunroad-consumption-curve)
- [x] SunRoad: home consumption ribbon along the arc (à la Helios) — 5 min homeCurve in DailyAccumulator, CT+feed-in otherwise feed-in only, orange sticks set back, common scale with production (2026-08-11, branch feat/sunroad-consumption-ribbon)
- [x] History: SmartMeter 3CT always shown without data — 3rd cause: tdengine returns the complete solarFlow structure all at zero; `hasEnergySignal` fix (non-zero value outside meta keys) in HistoryService, zero cache purged (2026-08-11, branch fix/smartmeter-history-zero-fields)
- [ ] v2.2: E/S cardinal letters mirrored depending on camera angle (SCNText to reorient — billboard or double-sided), street names, OSM vegetation/water bodies, neighborhood radius setting, stars at night, compass as an optional layer if missed, slim down SkyDomeView (keep ArrayPalette/PanelGlyph/Cardinal)

## Done
- [x] Sleep-resume fix (HTTP deviceList retry, PINGRESP timeout, didWake hook) + Debug card checkbox in History — lid test validated by Vincent, merged on main (1aba549); release 1.12.1 to be decided (2026-08-10)
- [x] Landing + FR/EN guide updated for 1.12 (History window card, historique.md/history.md pages, tables of contents and navigation) — merged on main, Pages redeployed (2026-08-10)
- [x] Release v1.12.0 (build 19): History window — merge, notarized DMG, GitHub release, appcast (2026-08-10)
- [x] Per-source metrics in History (selector per device card, limited to real fields, remembered choice) — test feedback validated (2026-08-10)
- [x] History module ported from ZendureCloud (kWh bars window 7/30/90/365 d, Zendure app private API, disk cache, 12 tests) — validated in testing then merged (2026-08-10)
- [x] Release v1.11.1 (build 18): cloud MQTT diagnostic patch — merge, notarized DMG, GitHub release, appcast, installed and verified (2026-08-10)
- [x] Cloud MQTT diagnostic patch (SUBACK parsed, takeover detection, deviceList filter) (2026-08-10)
- [x] Landing + FR/EN guide updated for 1.11 (auto-switch, collapsible cards, Home consumption card documented) — merged on main, Pages deployed (2026-08-10)
- [x] Release v1.11.0 (build 17): auto-switch + collapsible cards — merge, notarized DMG, GitHub release, appcast, installed and verified (2026-08-10)
- [x] Collapsible panel cards (header click, compact summary, persisted state) + visibility toggles in Settings → Affichage (2026-08-10)
- [x] "Basculer automatiquement" local ⇄ cloud option (2 local failures → Cloud if key; 60 s probe → back to local) (2026-08-10)
- [x] Release v1.10.4 (build 16): unreachable Smart CT state — merge, notarized DMG, GitHub release, appcast, installed and verified (2026-08-10)
- [x] UI: three Smart CT states (measured / configured-unreachable / not configured) in the Home consumption card and the dashboard legend (2026-08-10)
- [x] Release v1.10.3 (build 15): Home consumption card — merge, notarized DMG, GitHub release, appcast, installed and verified (2026-08-09)
- [x] "Consommation maison" card in the menu bar panel (CT total + detail per source, fallback without CT) + computation centralized in EnergyMath (2026-08-09)
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

- [x] Release v1.1.0 (graphs) — notarized DMG, GitHub release, appcast up to date (2026-08-04)

- [x] Menu bar display options (solar/battery/home toggles) (PR #5, 2026-08-04)
- [x] Launch at login (SMAppService) (PR #5, 2026-08-04)
- [x] Low-battery (SOC) alert, threshold 5–50 % (PR #5, 2026-08-04)
- [x] Today's energy counter (persisted per day) (PR #5, 2026-08-04)
- [x] Per-pack SOC/temp/power in battery card (PR #5, 2026-08-04)
- [x] Fallback host for VPN remote access + README section (PR #5, 2026-08-04)

- [x] Settings in tabs (5 tabs) (PR #6, 2026-08-04)
- [x] FR/EN localization (String Catalog) (PR #6, 2026-08-04)
- [x] Auto/Dark/Light theme (PR #6, 2026-08-04)
- [x] Light/dark screenshots in the README (PR #6, 2026-08-04)

- [x] Multi-day production history (Historique card, 14 d / 90 d) (PR #7, 2026-08-04)
- [x] Release v1.2.0 published (notarized DMG + Sparkle appcast) (2026-08-04)

- [x] macOS small/medium widget (App Group + JSON snapshot) (PR #9, 2026-08-04)
- [x] Control tab acMode/outputLimit/inputLimit (PR #9, 2026-08-04)
- [x] History CSV export (PR #9, 2026-08-04)
- [x] Release v1.3.0 published (2026-08-04)

- [x] App icon (PR #10, 2026-08-04)

- [x] Release v1.3.1 published (icon) (2026-08-04)

- [x] Vincent: widget added and validated (2026-08-04)
- [x] Vincent: Control tab validated on the real battery (2026-08-04)
- [x] Zendure Monitor card on lauriat.fr (+ llms.txt, counters 19→20), deployed (2026-08-04)

- [x] Remote-access VPN operational: Tailscale on [Mac-collecteur] (subnet router 192.168.x.0/24, route approved) + on the MacBook, fallback host [IP-SolarFlow-1] configured in the app (2026-08-04)

## Next
- [ ] 2-SolarFlow user: wait for their feedback on 1.11.1 (new takeover message? loop every ~15-30 s? Home Assistant/ioBroker/another Mac with the same Cloud Key? did Cloud work in 1.10.x?) (2026-08-10)
- [x] Vincent: first real test while traveling — validated on the morning of 2026-08-06 ("it worked very well" via Tailscale)
- [ ] **[Mac-collecteur]: prevent sleep** — confirmed asleep on the afternoon of 2026-08-06 (Tailscale `rx 0` → no remote access at all anymore): on site, `sudo pmset -a sleep 0 displaysleep 10` or Settings → Energy Saver
- [x] PR #16 merged + release **1.7.0** published (notarized DMG, GitHub release, Sparkle appcast, installed in /Applications with lsregister) (2026-08-06)
- [x] GitHub Pages build repaired (docs/.nojekyll — builds had been failing since v1.6.0) (2026-08-06)
- [x] lauriat.fr card moved to the **Domotique** category + llms.txt 1.7.0, deployed; vincentlauriat.github.io hub card refreshed (2026-08-06)
- [x] Complete documentation: FR+EN user guide in docs/guide/ + enriched README + GitHub wiki, new captures (2026-08-06)
- [ ] Back home: test wave 2 live (local polling, large widget, Soleil weather, Soleil window without scroll) — if local network KO: `lsregister -f` + restart (see MEMORY.md)
- [ ] Claude: propose the HC/HP optimizer plan (drives the real battery → Vincent's validation before any code)
- [ ] **2026-08-07 incident: SolarFlow faulted (no feed-in, full battery) AND off the network (ARP incomplete, ping/mDNS dead)** — Vincent's action on site: LED/official Zendure app (Bluetooth), hub restart
- [x] **Outage alerts (a, b, d)**: "device unreachable > N min" notification (default ON, 10 min adjustable), "zero production in broad daylight" notification (default ON, 30 min, sun > 20°), ⚠️ "hors ligne" menu bar icon — pure `OutageWatchdog` + 8 tests, 40/40 green, FR/EN (PR #17 merged, **release v1.8.0 published + installed**, 2026-08-07)
- [ ] **(c) Parse zenSDK state/error fields** — dump of the real `GET /properties/report` payload to do when the device is back, then display in the Appareil card + fault notification
- [x] **Sun window v3** (branch `feat/sun-panel-orientations`, 2026-08-08): multiple panel orientations (azimuth + tilt per array, `sunPeakWatts` migration), animated sky dome (real course of the day, solstices, production laid on the azimuth axis, orientation markers), solar compass with iso-incidence contours, per-array detail (yield, incidence, best hour, day potential), twilights + golden hours + next solstice, atmospheric transmittance in the yield model — 59 tests green
- [x] Regenerate `docs/guide/images/settings-sun.png` (2026-08-08): section extracted into `PanelArraysSection`, `SunSettingsTab` made internal, tab captured by the harness — along the way, fixed the shattered layout in the grouped `Form` and the loss of `sunPeakWatts` when deleting the last array
- [x] Sun window on a single screen + orientations adjustable in place (2026-08-08): three bands, 1400×980, content measured at 927 pt, azimuth/tilt sliders per array
- [x] Vincent: tilt slider **validated live** (2026-08-09, on a Debug build so the pessimistic case) — the harness's 60 ms/step measurement was indeed an upper bound due to forced layout, not the cost of a real drag
- [x] Branch `feat/sun-panel-orientations` pushed then merged `--no-ff` on `main` and pushed (`91575b5`, 2026-08-08) — landing, README and guide index updated in the same batch. **No release cut**, the tag is still to be arbitrated.
- [x] **Release 1.9.0 published** (2026-08-09): bump 1.8.0 → 1.9.0 / build 10 → 11, notarized and stapled DMG independently verified (`spctl` → `accepted, source=Notarized Developer ID`), GitHub release `v1.9.0` created **before** publishing the appcast (otherwise Sparkle clients hit a 404 download URL), appcast re-read online
- [x] ~~If dragging stutters: split the layers of `SkyDomeView`, or only persist on release~~ — moot, validated as smooth
- [x] 1.9.0 installed in `/Applications` (2026-08-09) + `lsregister -f` repair and Dock restart, with Vincent's explicit agreement — registration verified as `version: 11.0`, `spctl` still `Notarized Developer ID`
- [x] Repo cleanup (2026-08-09): only `main` left locally and on GitHub (5 + 5 branches deleted), after verifying none was unmerged; 11 tags intact
- [ ] Empty the 1.6.0 copy of the app left in the iCloud trash (`~/Library/Mobile Documents/.Trash/`): it remains a launch candidate in the Launch Services database
- [ ] Recheck the 1.9.0 "local network" authorization when the SolarFlow is back on the network — not testable end to end as long as no Zendure device advertises itself over Bonjour
- [ ] Exercise the "Ajouter un champ" button and the editor sliders (drawn by SwiftUI without a drivable AppKit view: out of the harness's reach, to cover in manual testing or via a UI test)

## Backlog (proposed on 2026-08-04, awaiting Vincent's arbitration)

### Fixes / robustness
- [x] 24/7 collector (Scripts/collector, LaunchAgent [Mac-collecteur], JSON API) + app integration (v1.4.0) — ⚠️ the local-network TCC unblocking on [Mac-collecteur] remains (Vincent's action)
- [x] Anti double-send + 0 W confirmation on Control (v1.4.0)
- [x] Zero line on the battery sparkline (v1.4.0)
- [x] "Aucun appareil trouvé" message (v1.4.0)
- [x] Unit tests (parser, SunCalc, Format — 9 tests) + GitHub Actions build+test on each PR (2026-08-05)
- [x] Widget: stale data grayed out + age (v1.4.0)
- [ ] Vincent: allow python3 "local network" access on [Mac-collecteur] (on-screen prompt or Settings → Privacy → Local Network) to unblock the collector

### UX improvements
- [x] Full "Tableau de bord" window with animated flow diagram + all indicators (temperature, RSSI, voltage, runtime, limits, SOC range) — Vincent's request, v1.4.0
- [x] Realistic flow diagram: solar/battery/grid → house breakdown, links animated only when the flow exists, watts on each link (2026-08-05)
- [x] Prominent "Ouvrir le tableau de bord" button in the panel + Dock/Cmd-Tab icon when the window is open (2026-08-05)
- [x] "Local network" TCC blocking detection banner with button to the settings + retry — Vincent's request (2026-08-05)
- [x] Flow diagram v3: SolarFlow central hub, batteries as satellite, + off-grid socket (`gridOffPower`) — Vincent's request (2026-08-05)
- [x] Sun module: local NOAA ephemerides (SunCard + lat/lon setting) — Vincent's request (2026-08-05)
- [x] Double-click on the panel's charts → dashboard — Vincent's request (2026-08-05)
- [x] "Utiliser la position de ce Mac" button (one-shot CoreLocation) for the Sun module — Vincent's request (2026-08-05)
- [x] Fix location button spinning in the void (timeout + service pre-check + distinct messages) (2026-08-05)
- [x] "Autorisations" section in Settings + startup warnings (local network, location, notifications) — Vincent's request (2026-08-05)
- [x] Sun module v2: dedicated "Soleil" window (outside the dashboard), sun path + production superimposed, theoretical yield (Wp × sin(elevation)), estimated efficiency (2026-08-05)
- [x] Local weather in the Soleil window: Open-Meteo, cloud cover, forecast sunshine, cloud-adjusted yield (2026-08-06, PR #16)
- [x] Vincent: unblock the local-network grant on his Mac — resolved on 2026-08-09: Mac restart + removal of the invalidation cause (adhoc Debug build launched from DerivedData, see "Resume after restart")
- [x] Period selector on the main graph: 15 min / Jour / 14 j (2026-08-05)
- [x] Large widget (systemLarge) with the 14-day histogram (2026-08-06, PR #16) — remaining: AppIntents refresh button
- [x] Optional notifications: full battery, unexpected grid draw, record of the day (2026-08-05)
- [x] Statistics: peak power of the day + comparison with yesterday under the histogram (record already present) (2026-08-05)
- [ ] 中文 localization (the site is trilingual, the string catalog makes it mechanical). Effort S.
- [ ] Card order customizable by drag-and-drop (MacInside pattern). Effort M.

### Evolutions
- [ ] **Off-peak/peak hours optimization**: local scheduler (mains charge at night off-peak, feed-in at peak) via `POST /properties/write` + € savings estimate. Effort L, very high value if HC/HP or Tempo tariff. Depends on the [Mac-collecteur] collector to be really useful.
- [x] GitHub Pages landing page — already existed, updated 1.7.0 + Pages build repaired (2026-08-06). Possibly remaining: dedicated page `outils/zenduremonitor/` on lauriat.fr (the card points to the GitHub Pages landing).
- [ ] iOS companion app (SwiftUI largely shareable, access via iOS Tailscale). Effort L.
- [ ] Multi-device Zendure support (aggregation of several SolarFlows). Effort M/L — useless as long as there is only one kit.
- [x] CO₂ avoided / € saved estimate (kWh tariff + g/kWh factor configurable) (2026-08-05)

### Code review fixes (2026-08-06)
- [x] Debounce polling restart (host typing / interval slider) (2026-08-06)
- [x] Remembered fallback host (retest of the primary every 2 min instead of every poll) (2026-08-06)
- [x] Data kept + grayed out offline instead of "Pas de données" (2026-08-06)
- [x] Day key in local time zone (was UTC via ISO8601) (2026-08-06)
- [x] Zero warnings: PermissionsStatus concurrency + widget CFBundleVersion synchronized (2026-08-06)
- [x] Daily solar breakdown (direct/stored + grid total) in the Flux card — the true self-consumption rate is impossible without a house meter (2026-08-06)
- [x] Unit tests on Monitor: pure `DailyAccumulator` extracted (bounded dt, rollover, buckets, peak, collector merge) + 8 tests — 28/28 green (2026-08-06, PR #16)
- [x] Release v1.6.0 published: notarized DMG + GitHub release + appcast + README, installed in /Applications (2026-08-06)

### Ergonomics (2026-08-05)
- [x] Juicy-style panel: header with icon buttons, removal of the bottom button row — Vincent's request
- [x] Settings reorganized: dedicated Soleil tab, Rafraîchissement in Appareil, lighter Général — Vincent's request
- [x] Docs + captures regenerated (panel light/dark, dashboard, sun) via ImageRenderer harness, README + landing page up to date, PR #13 merged (2026-08-05)
- [x] Release v1.5.0 published: notarized DMG + GitHub release + appcast + version installed in /Applications (2026-08-05)

### Cloud mode (2026-08-09, branch feat/cloud-mode)
- [x] Cloud layer ported from ZendureCloud into Sources/Cloud/ (CloudKey, SHA1-signed ZendureAPI, in-house MQTTClient, CloudDeviceState merge + conversions, CloudService, KeychainHelper) (2026-08-09)
- [x] Monitor: persisted Local/Cloud selector, pull adapter (cloudSnapshot, stale > 180 s), widened maxDt in cloud, read-only guard on writeProperties (2026-08-09)
- [x] Settings: source Picker, Cloud section (SecureField + key test + status + tracked device), Control disabled in cloud, fallback host hidden (2026-08-09)
- [x] 20 cloud tests ported (80/80 green) + 33 FR→EN strings (2026-08-09)
- [x] Scripts/cloud-probe.swift: probe of the account's MQTT topics/keys (home consumption / grid draw question via Smart CT) (2026-08-09)
- [x] Cloud mode tested live by Vincent: EU account connected, "Solar One" (SolarFlow 2400 Pro) on real-time MQTT flow (2026-08-09)
- [x] Cloud probe run live: no Smart CT on the account, no home consumption / grid draw key in the MQTT flow — unavailable cloud-side without pairing a Smart 3CT (2026-08-09)
- [ ] If a Smart 3CT is ever paired: redo the probe then "Consommation maison" and "Soutirage réseau" cards. Effort M.
- [x] The SolarFlow is back on the LAN ([IP-SolarFlow-1]): local mode retested and working with 1.10.0 installed (2026-08-09 evening)
- [ ] properties/write via MQTT (control in Cloud mode) — to validate carefully live first. Effort M.

### Energy flow diagram v2 (2026-08-09, branch feat/cloud-mode)
- [x] Aligned diamond (batteries right under the hub), animated halos consistent with the Soleil window, SOC pills per pack (2026-08-09)
- [x] "Not measured" arc Grid → House + explanatory note (no Smart CT: total house consumption unknown) (2026-08-09)
- [x] Verified in render (ImageRenderer harness, light/dark × 2 scenarios) (2026-08-09)

### Smart CT (2026-08-09, branch feat/cloud-mode)
- [x] Reinforced probe (wildcards, 180 s, app quit): the CT does not publish on the HA account's broker and is not in deviceList — but it answers LOCALLY (Bonjour _zendure._tcp + GET /properties/report) (2026-08-09)
- [x] SmartCT.swift (CTReport + parser tested on real payload), best-effort poll in Monitor (both modes), ctHost setting + Bonjour detection + test (2026-08-09)
- [x] Flow diagram: measured Grid → House arc (animated orange) + total house consumption when the CT answers; ctHost preconfigured on Vincent's side (2026-08-09)
- [ ] Historize the grid draw measured by the CT (daily total, dedicated card) — like energyTodayWh. Effort M.
- [x] Menu bar panel footer: connection mode (primary local / secondary local / cloud) + status pill (2026-08-09)
- [x] Settings reorganized: Réseau tab (Smart CT + fallback + collector), lighter Appareil tab, condensed help texts (2026-08-09)

### Release 1.10.0 (2026-08-09)
- [x] Bump 1.10.0 / build 12, release notes, README + landing + guide (Cloud Mode page FR/EN) (2026-08-09)
- [x] Merge --no-ff on main (c321637) + push (2026-08-09)
- [x] Notarized DMG (Accepted, stapled, independently verified: spctl Notarized Developer ID + codesign) + GitHub release v1.10.0 + appcast published after the release (asset verified HTTP 200) (2026-08-09)
- [x] Panel light/dark + dashboard captures regenerated (NSHostingView harness, opaque background against vibrancy, 1.10 synthetic data: connection footer, measured Smart CT arc, total house consumption) and merged on main (bca52fc) (2026-08-09)

- [ ] Cloud mode: map the `outputPower` of the `properties/energy` topic (~3 s) onto outputHomePower for a more reactive home flow than the reports (~5 s) — Vincent's question of 2026-08-09. Effort S.

### Resume after Mac restart (2026-08-09, local-network TCC incident)
- [x] Vincent: restart the Mac (done before the 2026-08-09 evening session)
- [x] Local mode revalidated (2026-08-09 evening): residual cause identified — an **adhoc Debug instance launched from DerivedData** was running instead of the installed app (each adhoc rebuild changes the signature → macOS invalidates the local-network TCC grant; the cloud, outbound Internet, is not affected). Fix: instances quit, **1.10.0 installed in /Applications** (notarized DMG, spctl accepted), lsregister -f + killall Dock, ghost copies unregistered from Launch Services (build/, DerivedData, iCloud trash) and builds purged. Local poll verified: widget-snapshot.json rewritten with fresh SolarFlow data.
- [x] Cut v1.10.1 with the Bonjour → IP discovery fix (13f2257) — done on the night of 2026-08-09: notarized + stapled + Sparkle DMG, GitHub release v1.10.1, appcast pushed after asset verification (HTTP 200), installed in /Applications, local poll verified
- [x] Merge `fix/energy-flow-no-crossing` (f6594e6, planar diagram without crossing — Vincent's request of the evening of 2026-08-09) on main (d72746f) and embed it in v1.10.1 — done
- [x] Regenerate the `docs/dashboard.png` capture — done on the night of 2026-08-09 (symmetric X + measured Smart CT, rebuilt harness, merged dae8967)
- [x] Merge `feat/energy-flow-mirror-layout` (8e33fd3, symmetric X) and release — done: v1.10.2 (build 14) published on the night of 2026-08-09, installed and verified
- [ ] v1.12: map `outputPower` (properties/energy, ~3 s) onto the home flow in cloud mode
