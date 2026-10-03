# PLAN — Zendure Monitor

## Phase 14 — v2.3 "Deux SolarFlow" (Two SolarFlows): first-class multi-device support (delivered: release v2.3.0 on 2026-10-03)

Trigger: Vincent added a second SolarFlow 2400 Pro (SN [SN-2], [IP])
next to the first one (SN [SN-1], [IP]); the app only saw one — single-device
architecture by design (one `deviceHost`, one `cloudDeviceKey`, one `state`).
Vincent's decisions: **total + detail** (one aggregated installation everywhere, plus an
"Appareils" (Devices) card); **address list prefilled by Bonjour** in local mode.

1. `DeviceState.combine` (pure, TDD) — powers summed, packs concatenated, SOC =
   average weighted by pack count (packs assumed to have the same capacity: each
   device has one type-500 pack and one type-350 pack, no capacity field in `packData`),
   device-specific scalars (`acMode`, limits, socMin/Max, temp., rssi,
   BatVolt, remaining runtime, SN, PV channels) → nil. Invariant: 1 device ⇒ identical.
2. `Monitor`: `deviceHosts: [String]` (migration materialized from `deviceHost`),
   parallel poll (TaskGroup), `fallbackHost` attached to the 1st device, `devices:
   [DeviceReading]` per device, aggregate **marked partial** if a device is missing,
   unreachable/anomaly watchdog per device, auto switch to Cloud only if ALL
   fail, return probe on any host.
3. Cloud mode: all devices in the deviceList aggregated (no more filtering on
   `cloudDeviceKey`), stale ones → partial.
4. Control: targets a specific device (sn + host) via a selector — never the aggregate.
5. UI: "Appareils" card (panel + dashboard), "partiel" (partial) banner,
   Settings → Network as an address list; Bonjour filtered on `solarFlow`.
6. Verification: tests, xcodebuild, PNG rendering of the 4-pack views, real-world trial ([IP] + [IP]).

## Phase 13 — v2.0 "Hélios 3D": the sun and the house in real 3D (in progress)

Brief: "the big novelty will be the 3D display of the sun and of the location, drawing
inspiration from the Home Assistant extension ReikanYsora/helios". Decisions validated with
Vincent on 2026-08-10: version number **2.0** (biggest visual evolution since the start),
**SceneKit** rendering (real native 3D, zero dependencies — Helios itself is 2.5D canvas,
we go further: extruded buildings, sun = real directional light, real cast
shadows, orbital camera).

### Existing building blocks reused as-is
- `SunCalc` (NOAA ephemerides: azimuth/elevation at any date, events, twilights)
- `SolarGeometry` + `PanelArray` (panel fields: peak power, azimuth, tilt)
- `LocationFetcher` (lat/lon), `WeatherService` (Open-Meteo: cloud cover)
- `Monitor` (live data: solar W, home W, SOC, grid, `todayCurve`)
- `HistoryService`/collector (past-day curves for the timeline)

### Phase A — SceneKit foundation (visible MVP)
1. "Hélios" window (`Window id "helios"`, WindowPolicy, indigo header button
   `cube.transparent` in the panel).
2. `HeliosSceneView`: `NSViewRepresentable` on `SCNView` — stylized ground + compass
   ring (graduated N/S/E/W), gradient sky background, constrained orbital camera
   (no passing below ground), ambient light + **directional light = sun**.
3. Sun arc of the day: 3D polyline sampled from `SunCalc` (10 min step),
   sun sphere at the current position, directional light aligned on it →
   shadows move with the real sun.
4. The house at the center (placeholder extruded box) + the user's panel fields
   as tilted planes (real azimuth/tilt), colored by incidence.

### Phase B — The location: the neighborhood in 3D (OSM)
1. `OverpassService`: building footprints around lat/lon (radius ~150 m,
   `way["building"](around:…)` on the public Overpass API), heights from the tags
   `height` / `building:levels` × 3 m (default 6 m).
2. Disk cache by rounded location (Application Support) — a single fetch,
   "Recharger le quartier" (Reload the neighborhood) button; without network or without data: the house alone,
   the scene stays usable.
3. `GeoProjection` (pure, tested): local projection in meters around the center
   (equirectangular — sufficient at neighborhood scale), then `SCNShape` extrusion
   of the polygons; the building closest to the center = the house,
   highlighted.
4. Real cast shadows (shadow mapping of the directional light) — the heart
   of the Helios effect: seeing the neighbor's shadow pass over its panels.

### Phase C — Energy in the scene
1. Animated flow beads (Helios-style): panels → SolarFlow → home / battery /
   grid, pace tied to live watts.
2. Production of the day along the arc (3D ribbon from `todayCurve`).
3. SwiftUI HUD over the scene: live W, SOC, weather — cloud cover
   darkens the sky and the light.

### Phase D — Timeline and polish
1. ±48 h time scrubber (like Helios): sun, shadows, light and curves
   follow; past days fed by the collector/cloud history.
2. Dynamic sky (night/dawn/day/dusk depending on elevation, stars at night),
   smooth transitions.
3. Clean "wall" mode (UI fades away), settings (neighborhood radius, default
   building height, shadow quality).
4. Tests (GeoProjection, Overpass parser, height mapping — pure), screenshots,
   README, landing, FR/EN guide.

### Identified risks
- **Overpass**: public API sometimes slow/limited → aggressive cache + clean
  degradation (house alone). Never blocking at launch.
- **SceneKit performance**: cap at ~200 buildings, merged geometries
  (`flattenedClone`), adjustable shadow quality.
- **SceneKit vs RealityKit**: SceneKit remains the right choice for macOS 14 without dependencies;
  the API is stable even if Apple eventually pushes RealityKit.

### Phase E — Sun → SunRoad merge (validated by Vincent on 2026-08-10)
A single solar screen: the 3D scene replaces the celestial dome and the compass (removed —
its information lives better in 3D), the rest of the Sun window migrates into a
**collapsible right side panel** (~330 pt, ScrollView of collapsible MetricCards):
1. **Panel fields** with the azimuth/tilt sliders — wired to the 3D view,
   the panel rotates in the scene during the gesture (PanelArrayRow/AngleSlider ported).
2. **Production**: the 14-day histogram (DailyBarChart) + total of the day.
3. **Ephemerides**, **Light and twilights**, **Theoretical yield**, **Weather** —
   cards ported as-is from SunView.
4. **Exact center point**: "Définir ma maison" (Set my house) mode — click on a building in the
   scene (SCNView hit-testing, named nodes) → its centroid becomes the reference
   position (`sunroadHouseLat/Lon`, takes priority over settings); possible return
   to the settings position.
5. The Sun window disappears: the orange sun button opens SunRoad, the cube button
   is removed (back to five actions). `SunView.swift` and `SunCompassView.swift`
   deleted; `SkyDomeView.swift` kept (hosts ArrayPalette/PanelGlyph/Cardinal).
   Configuration (position, adding/removing fields) stays in Settings → Sun.
Layout: full-frame scene on the left (HUD top-left, timeline at the bottom of the
scene only), right sidebar hideable (chevron, persisted) — wall mode hides
everything. 1400×980 window: the scene keeps ≥ 1000 pt of width.

### Release breakdown
- v2.0 when A + B + C + E are delivered (timeline D.1 is delivered); the rest of
  D may slip into 2.0.x. Each phase = a feature branch merged behind the
  previous one, tested in a signed local build before merge.

## Phase 10 — Cloud mode, Smart CT, flow diagram v2 (delivered in 1.10.0 on 2026-08-09)
Brief: "add a cloud mode to the application while keeping the local API mode" — protocol
taken from the project validated in real conditions `~/DevApps/Experimentations/ZendureCloud` (Cloud Key → SHA1-signed deviceList
→ real-time MQTT).

1. **Cloud layer ported** into `Sources/Cloud/` (zero external dependencies): `CloudKey`
   (base64 token → apiUrl + appKey, split at the last dot), `ZendureAPI`
   (`POST /api/ha/deviceList` SHA1-signed `C*dafwArEOXK`), `MQTTClient`/`MQTTPacket`
   (in-house MQTT 3.1.1 on Network.framework), `CloudDeviceState` (merging of partial
   reports + unit conversions + mapping to local `DeviceState`), `CloudService`
   (orchestration, 15 s reconnection via full re-login, 60 s getAll on a separate queue
   — documented deadlock pitfall), `KeychainHelper` (Cloud Key in the keychain,
   service `fr.lauriat.ZendureMonitor`, never UserDefaults).
2. **Pull adapter, single device**: the `Monitor` poll loop is unchanged;
   in cloud mode `refresh()` reads a merged snapshot (`cloudSnapshot()`, stale beyond
   180 s → error) — lastError, watchdog, isStale, notifications and widget work
   identically. The accumulator's `maxDt` widened to 180 s in cloud (spaced-out reports).
   Multi-device accounts: `cloudDeviceKey` Picker (default: first).
3. **Read-only in cloud (v1)**: MQTT `properties/write` never validated in real conditions →
   Control tab disabled, `ZendureError.cloudReadOnly` guard in `writeProperties`.
4. **Settings**: source Picker (Local API / Zendure Cloud) in the Device tab,
   Cloud section (SecureField + key test + phase status + tracked device),
   backup host hidden in cloud. No ATS/entitlements change (HTTPS + NWConnection).
5. **Ported tests** (`Tests/CloudTests.swift`): Cloud Key, signature, MQTT packets,
   merging/conversions, DeviceState mapping — pure cloud sources added to the test target.
6. **`Scripts/cloud-probe.swift`**: CLI probe that dumps all of the account's MQTT topics/keys —
   to check whether the Smart CT exposes global home consumption and grid draw.
7. EN translations + docs + green build/tests.

## Phase 9 — Sun window v3: panel orientations + animated hero (in progress 2026-08-08)
Brief: "more information and an incredible interface with animations with the sun on its orientations."

1. **Solar geometry** (`Sources/Shared/SolarGeometry.swift`, pure Foundation — also compiled in the widget):
   `PanelArray` (name, Wp, azimuth, tilt), JSON store with soft migration of `sunPeakWatts`,
   incidence cos, panel-plane factor (direct 85% / diffuse 15%, reduces exactly to
   sin(elevation) when flat), yield per field, best hour, clear-sky energy of the day,
   air mass, shadow length. Azimuth convention identical to `SunCalc` (0 = north, 180 = south).
2. **`SunCalc` extended without breaking changes**: sampled daily track (`track`), generic
   altitude crossings (civil/nautical/astronomical twilights, golden hour), declination and
   next solstice/equinox. Existing signatures unchanged (`OutageWatchdog` depends on them).
3. **Two animated visuals**: `SkyDomeView` (celestial dome — sky gradient depending on elevation, real
   daily track + solstice arcs, measured production, panel normals with incidence rings,
   animated halo/rays sun, stars at night) and `SunCompassView` (polar compass —
   azimuth × elevation, field sectors that light up according to incidence).
4. **`SunView` v3**: hero + compass + detailed card per orientation + enriched ephemerides
   (twilights, golden hour, day length delta, next solstice) + yield + weather.
5. **Settings → Sun**: multi-field editor (name, Wp, azimuth with cardinal label, tilt).
6. Tests (`SolarGeometryTests`, additions to `SunCalcTests`) + `project.yml` (new shared file
   explicitly listed in the test target) + EN translations + docs.

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

## Phase 8 — Outage alerts (done 2026-08-07, v1.8.0)
SolarFlow incident follow-up (injection fault with full battery, then device off the network, app silent):
1. Pure `OutageWatchdog` (Sources/Shared) + 8 tests — unreachable > N min, zero production in broad daylight. ✅
2. "SolarFlow unreachable" notifications (default ON, 10 min adjustable) and "Abnormal solar production" (default ON, 30 min, sun > 20°). ✅
3. ⚠️ "offline" menu bar icon. ✅
4. Release v1.8.0 (PR #17, notarized DMG, appcast, installed). ✅
5. Remaining (v1.9): parse the zenSDK state/error fields — dump of the real payload when the device is back.

## Phase 7 — Release 1.7.0 + documentation + discoverability (done 2026-08-06)
1. Merge PR #16 (wave 2) → release 1.7.0: notarized DMG, GitHub release, Sparkle appcast, installation in /Applications. ✅
2. Fix GitHub Pages build (docs/.nojekyll — broken since v1.6.0). ✅
3. Screenshots regenerated (ImageRenderer harness, wave 2 UI: Sun+weather, large widget). ✅
4. Complete documentation: docs/guide/ FR+EN (10 pages/language), enriched README, GitHub wiki. ✅
5. Landing docs/index.html updated (1.7.0 features + guide links). ✅
6. lauriat.fr: card in the Home automation category + llms.txt, deployed; github.io hub refreshed. ✅

## Phase 4 — Features & ecosystem (done 2026-08-04, v1.1.0 → v1.4.0)
- v1.1.0: MacInside-style charts (sparklines, circular gauge).
- v1.2.0: menu bar options, login item, SOC alert, daily energy, packs, backup host, tabbed settings, FR/EN i18n, themes, 14-day history.
- v1.3.0: macOS widget (App Group), Control tab (POST /properties/write), CSV export.
- v1.3.1: app icon (script-generated).
- v1.4.0: Dashboard window (animated flow diagram + complete indicators), 24/7 collector on [Mac-collecteur] (⚠️ local network TCC to unblock), fixes.
- Ecosystem: public repo + Sparkle releases, card + llms.txt on lauriat.fr (20th tool), Tailscale remote access ([Mac-collecteur] subnet router).

## Phase 5 — Next leads (backlog sorted in TODOS.md)
- Unit tests + GitHub Actions CI; period selector; large widget; additional notifications; stats; 中文; reorderable cards.
- Off-peak/peak optimization (v2.0); GitHub Pages landing page; iOS app; multi-device; CO₂/€.

## Phase 3 — Release (done 2026-08-04)
- Scripts/release.sh from Templates/Scripts/release-full.sh (Developer ID + notarization profile AppliMacVincentGithub + Sparkle EdDSA, no custom DMG background).
- Sparkle 2.9.1 integrated (new key, account "ZendureMonitor").
- git init, public repo vincentlauriat/ZendureMonitor, branch feat/initial-release → PR → merge.
- v1.0.0: notarized DMG in release/, GitHub release, appcast.xml on main.

## Phase 6 — Developing the TODOS ideas (in progress 2026-08-05, PR #13)
**Wave 1 (this session)**:
1. Dedicated "Soleil" (Sun) window (the dashboard stays a dashboard): "sun" Window scene, button in the panel footer, SunCard removed from the dashboard, shared Dock policy (counter). Sun module v2: sun course + production overlaid, clear-sky theoretical yield (configurable peak power × sin(elevation)), estimated efficiency.
2. Statistics: peak power of the day (persisted `peakW-<day>`), comparison with yesterday — under the histogram (panel + dashboard).
3. Period selector on the panel's main chart: 15 min / Day / 14 d (day curve in 5 min buckets persisted `solarCurve-<day>`).
4. Optional opt-in notifications: battery full, grid draw while solar is producing, production record broken.
5. Savings: € / CO₂ avoided (configurable kWh price + g/kWh factor) in the dashboard cards.
6. Tests (parser, SunCalc, Format → moved to Sources/Shared) without host app + GitHub Actions build+test workflow on PRs.

**Wave 2 (later)**: large widget, 中文, reorderable cards, off-peak/peak (after collector unblocking), landing page, Sun module weather, iOS, multi-device.

## Phase 7 — Backlog wave 2 (delivered 2026-08-06, PR #16 open — CI green, merge pending)
1. **Large widget (systemLarge)**: `WidgetSnapshot.dailyEnergy` (14 d, backward-compatible optional field), pure SwiftUI histogram + solar/battery/home header + total. AppIntents refresh button deferred.
2. **Sun window weather**: Open-Meteo `WeatherService` (HTTPS, no key, 30 min cache) — current state, cloud cover, forecast sunshine of the day; displayed in a Weather card of SunView.
3. **Monitor tests**: extraction of pure `DailyAccumulator` (bounded dt, day rollover, 5 min buckets, peak, solar/stored/grid cumulative totals) + tests; `Monitor.accumulateEnergy` becomes an adapter.
Deferred (Vincent's validation): off-peak/peak optimizer (dedicated plan — drives the real battery), 中文, reorderable cards.
