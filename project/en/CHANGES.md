# CHANGES — Zendure Monitor

## 2026-10-03 (control: reserve, max charge, feed-in — merged into main `0607492`, not pushed)

### Added
- Control tab, section **"Réserve, charge et injection" (Reserve, charge and feed-in)**: reserve (`minSoc`, 0-50%), maximum charge (`socSet`, 70-100%), **surplus feed-in** (`gridReverse` 1 allowed / 2 forbidden — confirmation recalling the Enedis CACSI convention), current values of each targeted device. Target **"Tous les appareils" (All devices)** (sequential send, stop with a message at the first failure). Note about Zendure's regulation overriding `outputLimit` and about smartMode (writes are not permanent).
- `DeviceState.gridReverse` / `feedInAllowed` (local + cloud parser, nil on the aggregate), "Injection du surplus" (surplus feed-in) row in the detailed Devices card. 26 English translations.

### Decisions
- Write scale: tenths of a percent (`minSoc` 20% → 200), like the official Zendure-HA integration (`number.py`: `int(self.factor * value)`, factor 10) — the zenSDK doc says "%" but the firmware returns 1000/100.
- `gridReverse` values: 0 disabled, 1 allowed, 2 forbidden (`entity.py` in Zendure-HA); only 1 allows export. Vincent's two SolarFlow units were at 2 → production throttled when the battery is full.
- No writes made to the devices by Claude: Vincent applies them from the tab.

## 2026-10-03 (red CI since v2.2.0)

### Fixed
- **GitHub CI failing since 08/13** (Sankey merge, 6 red runs including #62): `SankeyFlowView.swift:176` — `cannot assign value of type '(CGFloat, Double, CGFloat)'`. The `macos-latest` runner compiles with Xcode 26.6, which does not implicitly convert the Double `scale` to CGFloat; Xcode 27.2 / Swift 6.4 locally does — hence a working local build and intact releases. Fixed at the source: `scale` computed in CGFloat (`/ CGFloat(columnTotal)`), no numerical change. Branch `fix/ci-sankey-cgfloat`, **PR #18 green** (build + 124 tests on Xcode 26.6), merged (`a8fe539`) — `main` CI green again.

### Decisions
- Before merging a graphical view, do not rely on local Xcode alone (beta 27.x): CI is the only Xcode 26 compiler available — check its status after every push.

## 2026-10-03 (release v2.3.0)

### Added
- **Release v2.3.0 (build 23)** — multi-device. After Vincent accepted the Apple Developer agreement: 4.2 MB DMG **notarized Accepted** + stapled + validated + Sparkle-signed, GitHub release `v2.3.0` created **before** the appcast push (`1cf1044`), asset HTTP 200, appcast served at version 23. Installed **from the DMG**: `spctl` source=Notarized Developer ID, `codesign --deep --strict` OK, `stapler validate` OK; total verified live 973 W = 491 + 483 W, SOC 71% = (44+98)/2.

### Decisions
- To test notarization access, use a real `notarytool submit` (zip of a signed app, `--no-wait`): `notarytool history` succeeds even without an agreement in force and gave a false green light.

## 2026-10-03 (v2.3.0 preparation — blocked at notarization)

### Docs
- Branch `release/2.3.0`: bump 2.3.0 / build 23, README "New in 2.3" + roadmap (v2.3 multi-device checked, SunRoad → v2.4, optimizer → v2.5), landing card "Several SolarFlow, one installation", `release/release-notes-2.3.0.md`. 124 tests green.

### Blocked
- `xcrun notarytool` → **HTTP 403 "A required agreement is missing or has expired"** (two attempts). Apple Developer agreement to be accepted by Vincent; `release.sh` not run. `main` pushed (`1030941`) without the appcast: no users affected.

## 2026-10-03 (multi-device: two SolarFlow aggregated — branch feat/multi-device)

### Fixed
- **The app only saw one of Vincent's two SolarFlow units** (2nd device added: SN [SN-2] at [IP], next to [SN-1] at [IP]). Root cause: **single-device by design** architecture — a single `deviceHost` polled locally, a single `cloudDeviceKey` tracked in the cloud, a single `DeviceState` consumed everywhere. Not a discovery flaw: both advertise over Bonjour and answer on `/properties/report`.

### Added
- `DeviceState.combine` (pure, 7 tests): powers summed, packs concatenated, SOC weighted by pack count (no capacity field in `packData`; each device has one type-500 pack and one 350), single-device values (SN, PV channels, limits, AC mode, socMin/Max, temp., rssi, BatVolt, autonomy) → nil. Tested invariant: a single device ⇒ strictly identical state.
- `DeviceReading` + `Monitor.devices`: per-device reading (host that answered, state or error). **"Appareils" (Devices)** card (`Components/DevicesCard.swift`) in the panel (compact: solar, SOC + battery flow, feed-in, host) and in the dashboard (detailed: + PV channels, temperature, Wi-Fi, AC mode, limits, charge range) — replaces the "Appareil" (Device) card when there are several.
- **Partial totals flagged** (`partialMessage`) when a device is missing: orange banner in panel + dashboard, the sum is never presented as complete.
- **Per-device** watchdog: zero-production anomaly in broad daylight per SolarFlow (otherwise drowned in the sum), "Un SolarFlow ne répond plus" (A SolarFlow is no longer responding) notification when the others respond. A total outage keeps the historical alert.
- English translations of the 20 new strings in `Localizable.xcstrings` (compact catalog format preserved).

### Changed
- Settings → Device: **address list** (add/remove, test all hosts), "Rechercher sur le réseau" (Scan the network) offers "Ajouter" (Add) per device found and excludes the Smart CT (which also advertises as `Zendure-…`).
- Local poll **in parallel** (TaskGroup) — a powered-off device no longer adds its 5 s timeout to the cycle. `fallbackHost` attached to the first device. Auto switch to Cloud only if **all** fail; return probe on any host.
- Cloud mode: all devices of the deviceList aggregated (the "Appareil suivi" (Tracked device) picker and `cloudDeviceKey` disappear; stale/missing → reading in error → partial totals).
- **Control**: targets a specific device (SN + host that answered) via a picker when there are several — never the aggregate, whose SN is nil so that no forgotten path can drive a battery blindly.
- Setting `deviceHost` → `deviceHosts` (array), **materialized migration** on open; `deviceHost` is still written with the first host (rollback to an earlier version possible).

### Changed (continued, same day)
- **Low / full battery alerts per device** (Vincent's choice): pure logic `Shared/BatteryAlerts.swift` (5-point hysteresis, one send per episode, per-device `socMax` ceiling, 4 tests including "one empty + one full = alert despite the 55% average"). With a single device, notification titles and identifiers unchanged; with several: "Batterie faible — SolarFlow 2" (Low battery — SolarFlow 2), id suffixed per device.
- Merged `--no-ff` into `main` (not pushed).

### Verified
- 124 tests green (113 + 7 aggregate + 4 alerts). `xcodebuild` OK.
- Developer ID-signed Release build installed in `/Applications` in place of the notarized 2.2.0 (rollback: 2.2.0 DMG in `release/`): migration observed (`deviceHosts = [.46]`), then two hosts → widget snapshot 641 W for 494 + 146 W measured directly, SOC 72% = (46 + 98)/2; second reading 499 W / 73% for 501 + 0 W, SOC 46 and 100.
- Off-screen PNG rendering **looked at** (throwaway `swiftc` harness, dark and light themes): compact card, detailed card, unreachable device, flow diagram and 4-pack Sankey. One defect fixed before closing: truncated SN + unreadable IP in the compact card → host only.
- **Cloud mode verified live** through the app itself (auto switch disabled for the duration of the test, settings restored afterwards): aggregated SOC 73.5% = (47 + 100)/2 → both devices are in the deviceList and aggregated. A first CLI probe of the deviceList was abandoned: `security find-generic-password` opened a Keychain access prompt on Vincent's side.
- **Not verified**: the Settings tab (no rendering possible without `Monitor`).
- **24/7 collector (`[collector-host].local:8899`) is single-host** (`ZENDURE_HOST=.46`) and **effectively stopped** (`/health` → `lastSample: null`, `/today` → 0 Wh). The app keeps the max between its own total and the collector's: while it runs, the sum of both devices wins. Collector not modified (deployed on [Mac-collecteur]).

## 2026-08-14 (PRD)

### Docs
- **`PRD.md` created** at the root (French, gitignored with the other session docs) — retroactive and prospective PRD: formalizes the product as shipped in 2.2.0 and frames v2.3/v2.4. 14 sections: executive summary, context/problem, 5 guiding principles, personas and non-targets, scope, 56 numbered functional requirements (F-01…F-94, 10 domains, status shipped/planned/exploratory), non-functional requirements, architecture, data sources, user journeys, metrics, roadmap, risks, open questions.
- The guiding principles are not invented after the fact: they are extracted from the trade-offs actually traced in `MEMORY.md` (local first, read-only by default, data honesty, no superfluous dependency, "a view that compiles is not a view that works"). The PRD makes explicit that the hatched out-of-scale band in the Sankey and the "not measured" arc in the diagram are two consequences of the same principle.
- Four open questions logged for arbitration: multi-device, autonomous write margin of the v2.4 optimizer (a break with the read-only principle), future of the 24/7 collector given the History via the mobile API, signal justifying Chinese localization.

### Changed
- `.gitignore`: added `PRD.md` to the "Claude session docs" section. **Only tracked change of the session, not committed** (not requested).

### Decisions
- The PRD is **in French and gitignored**, consistent with `PLAN.md`/`MEMORY.md`: it is an internal working document, and it cites personal infrastructure details. To be switched back to English and versioned if the PRD is to become public.
- Documentation roles settled: **PRD** = what and why (scope, principles, requirements, risks) · **PLAN** = execution breakdown · **TODOS** = progress · **MEMORY** = lived state, decisions and pitfalls · **README/guide** = public documentation.

## 2026-08-13 (release v2.2.0)

### Added
- **Release v2.2.0 (build 22)**: the Sankey reading of the energy flow. Bump via `release/2.2.0` (`53d0c76`), 4.1 MB DMG **notarized Accepted** + stapled + validated + Sparkle-signed, GitHub release `v2.2.0` created **before** the appcast push (`76f45a8`), asset verified HTTP 200. Installed **from the DMG** then relaunched: `spctl` accepted **source=Notarized Developer ID**, `codesign --verify --deep --strict` OK, `stapler validate` OK, version 2.2.0 build 22 confirmed, fresh widget snapshot (11 s). 113 tests green before release.

### Docs
- **Landing page** (`docs/index.html`): "Energy-flow dashboard" card rewritten as "Energy flow — two readings", dashboard section completed, **second figure** with the Sankey screenshot and a caption explaining what the diagram cannot show.
- **README**: "New in 2.2" paragraph, roadmap — v2.2 checked on the Sankey, the old v2.2 backlog slid to v2.3, the optimizer to v2.4.
- `release/release-notes-2.2.0.md`.

## 2026-08-13 (app relaunched with the Sankey)

### Changed
- **Local Developer ID-signed Release build installed in `/Applications`** in place of the notarized 2.1.0, app relaunched (PID 57593). `Scripts/release.sh` procedure without DMG or notarization: `ditto --noextattr` staging, deepest-first codesign (appex + entitlements → Sparkle binaries → framework → app, Hardened Runtime + timestamp). Independent checks: `spctl` accepted / source=Developer ID, `codesign --verify --strict --deep` OK.

### Note
- ⚠️ The version did not change (**2.1.0 build 21**): the installed app contains the Sankey but is **not notarized**, Sparkle will offer no update, and reinstalling from the 2.1.0 DMG would lose the view. **A 2.2.0 release is needed to distribute the Sankey.**

## 2026-08-13 (versioned release notes + root cause in the script)

### Fixed
- **`release/release-notes-2.1.0.md` was not tracked** — the only missing version out of 21, the other 20 having always been versioned. Committed.
- **Root cause in `Scripts/release.sh`**: the end-of-script reminder ("Next steps") only asked to commit `appcast.xml`, never the release notes — even though they are versioned and the DMG, on the other hand, is gitignored. The reminder now includes `release/release-notes-$VERSION.md`, otherwise the oversight would recur at every release.

### Note
- My initial reading of `CLAUDE.md` ("release artifacts must be gitignored") was too broad: the rule targets binaries (`*.dmg`, `*.zip`), and actual repo practice versions the release notes. Repo practice prevails.

## 2026-08-13 (Sankey merge + screenshots redone)

### Changed
- **`--no-ff` merge of `feat/sankey-energy-flow` into main** (`8d9dc08`) — not pushed.
- **Dashboard screenshots redone on real data** (local poll, 16:48:18, 435 W solar / 1.19 kW grid / Home 1.63 kW, sparklines with 131 points): `docs/dashboard.png` (diagram, 144 dpi) and `docs/guide/images/dashboard-light.png` (72 dpi) now show the Schéma/Sankey selector; two new ones, `docs/dashboard-sankey.png` and `docs/guide/images/dashboard-sankey.png`, show the Sankey reading **at the same instant and with the same figures** — so the comparison is valid. README and fr/en guides updated to reference them.

### Decisions
- **Screenshot rendering goes through `NSHostingView.cacheDisplay`, not `ImageRenderer`.** `ImageRenderer` replaces a segmented `Picker` with a yellow crossed-out rectangle — and that is precisely the new control to document. `cacheDisplay` renders native AppKit controls. (The dashboard content is 1051 pt tall for a 720 window: a window screenshot cannot show it in full, hence the off-window rendering.)
- **Throwaway capture harness, outside the repo**: the app sources compiled separately (`swiftc`, `Updater` stubbed since Sparkle is not linkable), packaged as an `.app` under a **distinct** bundle id (`fr.lauriat.ZendureMonitorShots`) with a **copy** of the preferences — the harness never writes to the real app's domain, Vincent's daily accumulator is not touched. Since the sparklines live in memory (one point per poll), the harness warms up for 5 min at a 2 s poll before rendering.

## 2026-08-13 (Dashboard: Sankey diagram as a second representation)

### Added
- **`SankeyFlowView`** — second reading of the dashboard flows, next to the nodal diagram: ribbon width equals watts, so the split (solar → home vs solar → battery) reads at a glance. Three columns (sources / SolarFlow / uses), cubic ribbons, animated dashes in the real direction at a speed tied to power (same language as `EnergyFlowView`, median axis drawn in thick dashes then clipped by the ribbon). SOC + per-pack SOC carried by the Batteries node, temperature by the hub label: the Sankey view loses no information from the diagram.
- **Segmented "Schéma / Sankey" selector** in the Energy flow card, choice persisted (`@AppStorage("energyFlowStyle")`, enum `FlowStyle`). Placed in the card content, not in `MetricCard` (component shared with MacInside — zero blast radius).

### Decisions
- **The hub imbalance is materialized, not absorbed.** A Sankey visually asserts conservation; the SolarFlow never balances exactly (conversion losses, measurement noise). Explicit gray ribbon, symmetric in both directions: "Pertes & conversion" (Losses & conversion) if inputs > outputs, "Écart de mesure" (Measurement gap) otherwise. Both columns thus have the same height by construction.
- **The unmeasured direct draw keeps a FIXED, hatched thickness**, off scale, and caps the Home node bar the same way. Giving it a proportional width would invent a value, omitting it would assert it is zero — this is the point where a Sankey lies most easily, since it claims to show everything.
- **Columns aligned at the top, direct draw in the top slot of both columns**: it then flows in the free band above the hub bar and **crosses no other ribbon**, with no ordering heuristic.
- **No floor thickness on ribbons**: a per-flow minimum would throw the sum of ribbons off from the node bar height. Flows ≤ 1 W (same threshold as `EnergyFlowView`) are dropped, the rest is strictly proportional.
- **Identical values in both views** — `EnergyMath.gridToHome` / `homeTotal`, signed `batteryFlow`, `flowText` (▲/▼) and `Format.watts` reused as is: switching from one representation to the other never changes a label.


### Fixed (after visual verification — three defects that code review had not caught)
- **Dashes covered the whole ribbon thickness.** A stroke as wide as the band produces slabs perpendicular to the path, which pinch in the curves: on the 240 pt solar ribbon, the rendering was a barcode, not a flow. Dashes now run on **parallel lanes** inside the ribbon (one lane every ~16 pt, 6 at most, thickness capped at 6 pt).
- **Labels overlapped and left the view.** Two thin neighboring nodes at the bottom of a column (off-grid socket + balance ribbon) stacked their texts. Downward then upward **spreading** pass per column, like axis labels; text columns widened (0.24 / 0.76 instead of 0.19 / 0.81) — "+ réseau : non mesuré" and "consommation totale" were truncated on the right.
- **The hub label landed on the lowest ribbon**: it is now placed in the reserved bottom margin, below the foot of the columns.

### Fixed
- Zero-flow guard: the scale would divide by zero every night (NaN in the `Path`s) — `makeLayout` returns `nil` below 1 W and the view shows a "Aucun flux mesurable" (No measurable flow) state with the SOC. Also matters for the `ImageRenderer` rendering of `DashboardContent`.

### Docs
- README (Dashboard section: the two readings), guide `fr/tableau-de-bord.md` + `en/dashboard.md` (Diagram / Sankey sections, with the two reading points: hub balance, unmeasured flow).
- `Localizable.xcstrings`: 9 English keys added (Représentation, Schéma, Sankey, Aucun flux mesurable, Écart de mesure, Pertes & conversion, entrées/sorties, soutirage direct) — automatic extraction had produced nothing, the English UI would have stayed in French across the whole view.

Build green, 113 tests green. **Verified on screen**, not just on paper: the five states (production without CT / with CT at 1.40 kW / night discharge with and without CT / idle) rendered to PNG via `ImageRenderer` in a throwaway harness outside the project, and looked at. Confirmed: equal-height columns, direct draw passing above the hub **crossing no ribbon**, hub sized on what really passes through it (at night: 460 W in the hub while 1.25 kW bypasses it), Home 2.33 kW = 1400 + 934. Branch `feat/sankey-energy-flow` — **validation by Vincent in the app pending** (off-app rendering lacks the materials and theme).

## 2026-08-11 (release v2.1.0)

### Added
- **Release v2.1.0 (build 21)**: SunRoad curves (24 h consumption à la Helios + clear-sky forecast production on a common scale, "⌂ W" badge), SmartMeter 3CT History fix (zeros ≠ data), notASolarFlow guard on the local poll. Merge `feat/sunroad-curve-tuning` (`8ab0865`), bump `release/2.1.0` (`ce1d2a4`), 4.0 MB DMG notarized (Accepted) + stapled + Sparkle-signed, GitHub release `v2.1.0` created before the appcast push (`4b353fd`), asset HTTP 200. Installed from the DMG (note: mount point with a space), spctl `Notarized Developer ID`, codesign strict OK, build 21 confirmed, fresh snapshot. README: "New in 2.1", roadmap v2.1 checked, backlog renumbered (v2.2 polish, v2.3 optimizer).

## 2026-08-11 (SunRoad: production laid on the ground, forecast/actual comparable)

### Changed
- **Production leaves the underside of the arc for the ground**: the sticks hung from the arc (whose height varies — non-horizontal zero), so the forecast was not visually comparable. Actual (turquoise sticks) and forecast (yellow curve) now share the **same hour circle on the ground** (`productionRadius = domeRadius - 8`, consumption stays at `- 14`), the same base and the same scale (max of the two peaks); peak height common to the three series (`curveMaxHeight = 26 m`). Each stick must touch the curve if the day keeps its promise. Guide fr/en rewritten. 113 tests green. Branch `feat/sunroad-curve-tuning` (`c2c7552`), local app relaunched — **not merged**.

## 2026-08-11 (SunRoad: consumption curve ×2 + forecast production curve)

### Changed
- **Consumption curve twice as tall** (26 m at the peak instead of 13) — visual feedback from Vincent.

### Added
- **Forecast production curve** under the arc: the **clear-sky** yield (`SolarGeometry.clearSkyWatts`, same assumptions as the sidebar's Yield card) of the configured arrays, one point per quarter hour at the real sun positions, in translucent yellow. **Common scale** with the actual sticks (max of the two peaks): the forecast/actual gap reads directly. The curve follows the **±48 h timeline** (it is also drawn outside the current day, without the actual) and is recomputed when the **orientation sliders** move. Guide fr/en. 113 tests green. Branch `feat/sunroad-curve-tuning` (`3089a11`), installed locally for visual validation — **not merged**.

## 2026-08-11 (merge + local deployment: consumption curve + CT guard)

### Changed
- **`--no-ff` merge into main and push** (`a7b548e..3af52ea`): `fix/reject-non-solarflow-payload` (`2c95f67`) and `feat/sunroad-consumption-curve` (`3af52ea`), 113 tests green, branches deleted. Signed Release rebuild + reinstall in /Applications + relaunch: fresh snapshot (925 W solar / 699 W home / SOC 18%), today's consumption curve populated. Still relevant: `deviceHost` → `.46` (user setting) and a 2.0.1 release for Sparkle.

## 2026-08-11 (SunRoad: consumption as a continuous curve à la Helios)

### Changed
- **Home consumption is no longer in sticks under the arc** (hard to read: spaced out, daytime hours only) but in a **continuous blue curve on the full hour circle**, like Helios: each 5 min slice is placed at the sun's azimuth of that instant (night goes to the north side), height is proportional to watts (normalized on its own peak, radius `domeRadius - 14`), with translucent **vertical stakes** every quarter hour. New **"⌂ n W" badge** facing the camera above the house (instantaneous CT consumption + feed-in, rebuilt in 10 W steps). The production ribbon stays as turquoise sticks under the arc, scaled to its own peak. Everything follows the Energy checkbox. Guide fr/en rewritten. 111 tests green.

## 2026-08-11 (local poll: reject the payload of a Smart CT mistaken for a SolarFlow)

### Fixed
- **The local poll "succeeded" on the wrong box**: DHCP moved the Smart CT from `.31` to `.20`, `deviceHost` was set to `.20` — and since both devices expose the same `GET /properties/report` API, `ZendureParser.parse` (which required no field) turned the meter's payload into an all-zero `DeviceState` displayed as a real measurement: no more production visible locally, and the auto switch probe "succeeded" too → oscillations local (false) ⇄ cloud (true). Guard added: payload containing `total_power`/`a_aprt_power` → dedicated `notASolarFlow` error ("Cette adresse répond comme un Smart CT…" — This address responds like a Smart CT…), payload with none of the 17 SolarFlow signature fields (`sn`/`rssi` excluded, the CT publishes them too) → `badPayload`. A poll on the wrong address now fails outright (watchdog and auto switch see it). 2 tests added, 113 green. Remaining on the settings side: `deviceHost` → `[IP-SolarFlow-1]` (the SolarFlow, verified by probe).

### Decisions
- Network diagnosis of the day: SolarFlow still at `[IP-SolarFlow-1]` (58 keys, values consistent with the cloud), Smart CT now at `[IP-SmartCT]` (sn `61u1m6E3`), `.31` dead. `ctHost = [IP]` is correct; only `deviceHost` needs fixing.

## 2026-08-11 (merge + local deployment of the two changes of the day)

### Changed
- **`--no-ff` merge into main and push** (`002162f..a7b548e`): `fix/smartmeter-history-zero-fields` (`e2c3567`) and `feat/sunroad-consumption-ribbon` (`a7b548e`), 111 tests green on merged main, branches deleted. **App relaunched as a local build**: Release + Developer ID signature (release.sh procedure without DMG/notarization; `build/` purge required, the SPM cache pointed to the old `DevApps/SolarTools` path), installed in /Applications, poll verified (4 s snapshot), `homeCurve-<day>` persisted (~2.6 kW — CT active). ⚠️ The build 20 in place is no longer the notarized version: plan a **2.0.1 release** to distribute via Sparkle.

## 2026-08-11 (SunRoad: home consumption ribbon along the arc)

### Added
- **Consumption ribbon in the SunRoad scene** (à la Helios, which stands up production AND consumption along the sun's path): second set of **orange** sticks, set back (radius `domeRadius - 10`) under the turquoise production ribbon (`domeRadius - 5`), one stick per quarter hour at the real sun position, **common scale** (max of the two peaks) to compare production and consumption at a glance. Data: new 5 min curve `homeCurve`/`homePeakW` in `DailyAccumulator` (`home` parameter of `ingest`, default 0), fed in `Monitor.accumulateEnergy` by `EnergyMath.homeTotal` (Smart CT + feed-in) when the CT responds, `outputHomePower` alone otherwise — same convention as the flow diagram. Per-day persistence (`homeCurve-<day>`/`homePeakW-<day>`), `pruneAuxKeys` purge extended. Guide fr/en `sunroad.md` updated. Test `testHomeCurveBucketsKeepMax`, 111 tests green.

## 2026-08-11 (History: SmartMeter 3CT finally hidden — zeros are not data)

### Fixed
- **The SmartMeter 3CT still appeared in History with no data**, despite the two fixes of 2026-08-10. Real cause seen in the disk cache (`Application Support/ZendureMonitor/history/[deviceId].json`): the tdengine endpoint answers it with the **full** solarFlow structure (15 fields: solar, home, batteryInput…) but with **all values at 0** — the presence tests (`totals.isEmpty`, `!fields.isEmpty`) therefore never marked it `unsupported`. Fix: new `ZendureAppAPI.hasEnergySignal(_:)` (at least one non-zero value, excluding the `type`/`productType` meta keys) used everywhere in `HistoryService` (lifetime totals probe, carrying days, safety net after retrieval). On the next load, the 3CT becomes `unsupported` and its cache of 91 days of zeros is purged. A new SolarFlow with no production would be hidden the same way — it reappears as soon as the first non-zero value arrives (the probe is redone on every load). Test `testHasEnergySignal` added, 110 tests green.

## 2026-08-11 (SunRoad screenshot in the docs)

### Docs
- **SunRoad screenshot** (2200×1520, taken by Vincent on real data: 39 buildings, amber house, timestamped arc, timeline, sidebar) integrated into the landing (dedicated figure), at the top of the guide pages `fr/sunroad.md`/`en/sunroad.md` (copy `guide/images/sunroad.png`) and in the README. Branch `docs/2.0-sunroad-screenshot` (`dc57500`) merged into main (`002162f`), pushed. Spotted on the screenshot: cardinal letters E/S mirrored depending on camera angle → v2.1 backlog.

## 2026-08-11 (release v2.0.0)

### Added
- **Release v2.0.0 (build 20)**: SunRoad. `--no-ff` merge of `feat/helios-scene` into main (30 files, +1757/-844), bump via `release/2.0.0`, 4.0 MB DMG notarized (Accepted) + stapled + Sparkle-signed, GitHub release `v2.0.0` created before the appcast push (`2bb18e9`), asset verified HTTP 200. Installed from the DMG (lsregister procedure, build 20 confirmed), independent checks OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), relaunched, local poll verified. Merged branches deleted. Release notes: full SunRoad (OSM neighborhood, real shadows, animated flows, timeline, Sun merge, house on click), History window (first Sparkle vector for 1.11 users) and recovery after sleep. Remaining: SunRoad screenshot (window closed during the release — to be done by Vincent, then integration into landing/guide).

## 2026-08-10 (SunRoad: neighborhood lost after the house click; History: SmartMeter)

### Fixed
- **Empty neighborhood after "Définir ma maison" (Set my house)** (experienced as "the click doesn't work"): the click worked — but recentering changed the cache key (1e-4° rounding), triggered an often-throttled Overpass refetch, and the screen fell back to an empty neighborhood. Two fixes: buildings and roads are **also rebuilt when the origin changes** (`originKey` — OSM coordinates are absolute, only the projection moves: the pick realigns the scene instantly, with no network); and `loadNeighborhood` **falls back to the neighboring cache** (settings key, then effective key) when the fetch fails.
- **History: the SmartMeter appeared without data** — the solarFlow tdengine endpoint does not cover it. The service now probes the **lifetime totals first**: empty totals and no **field-carrying** day → device `unsupported`, hidden from the window (discreet note) and never queried over 365 days; empty days already in cache (harvested before this filter) don't count and are purged, and a safety net after retrieval covers the case of fresh days all empty. A failing device no longer condemns the loading of the others (per-device catch).

## 2026-08-10 (SunRoad: test feedback fixes — house click and eye)

### Fixed
- **"Définir ma maison" (Set my house) not working**: with `allowsCameraControl`, `SCNView`'s internal gesture recognizers take precedence over the `mouseDown` override — the designation click never arrived. Replaced by an `NSClickGestureRecognizer` added to the view (installed from `makeNSView`), which coexists with the orbital camera (it only uses the drag); hit-testing unchanged.
- **The eye now hides only the information banner** laid over the 3D — the timeline and the side panel cards remain visible (Vincent's request). Help labels and FR/EN guide pages aligned.

## 2026-08-10 (v2.0 Phase E — Sun → SunRoad merge)

### Changed
- **The Sun window merges into SunRoad** (Vincent's decision, layout validated): full-frame 3D scene on the left, **right side panel** (332 pt, hideable, persisted) in collapsible cards inherited from Sun — Panel arrays with **azimuth/tilt sliders wired to the 3D** (the panel rotates in the scene during the gesture), Production (14-day histogram + day total + peak), Ephemeris, Light and twilights, Theoretical yield, Weather. The **solar compass is removed** (its information lives better in 3D). The orange sun button opens SunRoad, the indigo cube disappears (back to five actions), window 1400×980.
- `SunView.swift`, `SunCompassView.swift`, `SunCard.swift` deleted; `SkyDomeView.swift` kept (hosts `ArrayPalette`/`PanelGlyph`/`Cardinal`, to be slimmed in 2.1). The "not configured" screen points to Settings → Soleil (where position and arrays are still configured).

### Added
- **"Définir ma maison" on click**: house menu in the HUD → clicking a building in the scene (`PickableSCNView`, hit-testing on `building-<i>` nodes) makes its centroid the **exact center** (`sunroadHouseLat/Lon`, takes priority over settings) — projection, house detection, ephemeris and neighborhood realign on it; "Revenir à la position des réglages" (Return to the settings position) cancels.
- Docs: `soleil.md`/`sun.md` deleted, `sunroad.md` FR/EN enriched (sidebar, house on click), tables of contents renumbered (12 entries), navigation rewired (0 broken links verified), landing (card "Sun analytics — now inside SunRoad", dashboard section without the obsolete screenshot), README (merge mentioned, roadmap). 109 tests green, build with no warnings.

## 2026-08-10 (v2.0 Phases C + D — energy in SunRoad, timeline, weather, wall mode)

### Added
- **Phase C — energy in the scene**: `SunRoadFlows` (watts quantized into 0–4 beads per tier: ≤150/≤500/≤1200/+), 3D anchors (grid pylon to the north-east, battery block against the house — Energy layer), **animated emissive beads** at constant speed in a staggered string on 4 flows (panels→house yellow, pylon→house orange, house↔battery green/orange), **production ribbon on the arc** (one stick per quarter hour at the real sun position at that instant, height ∝ W/day peak). `Monitor` injected into the window.
- **Phase D — timeline, weather, wall mode**: **±48 h** slider at the bottom of the window (sun, shadows, sky and arc follow; "Maintenant" (Now) button; ribbon hidden outside the current day), **Open-Meteo weather in the scene** (cloud cover → directional light veiled up to -55%, grayed sky — night stays night), **wall mode** (crossed-out eye → interface erased, discreet reminder eye), energy HUD row (solar, home, SOC, clouds), "Énergie" (Energy) checkbox.
- **Complete v2.0 docs**: guide pages `fr/sunroad.md` + `en/sunroad.md`, tables of contents renumbered (SunRoad at 7, 13 entries), navigation rewired (0 broken links, verified), panel pages "six actions" (indigo cube), card "🧊 SunRoad — your home in 3D" on the landing, README "New in 2.0" + roadmap (v2.0 checked, 1.13 remainder → v2.1, optimizer → v2.2). 109 tests green, build with no warnings.

## 2026-08-10 (SunRoad: layers visible on demand)

### Added
- **Visibility checkboxes in the SunRoad HUD**: five toggleable layers — Buildings (includes the placeholder house when OSM has not answered), Roads, Sun arc (directional lighting always stays active), Panels, Compass. `SunRoadVisibility` applied via `isHidden` on the scene containers (ring + cardinals grouped in a `compassNode`), choices persisted (`sunroadShowXxx`).

## 2026-08-10 (SunRoad: the neighborhood roads)

### Added
- **OSM roads in the SunRoad scene** (test feedback: "more detail in the 3D"): the Overpass query also brings back `way["highway"]` (170 m radius, a bit further than buildings — they structure the view), width deduced from the class (motorway 9 m → footpath 1.8 m, default 4 m), rendered as flat ribbons at ground level — oriented `SCNBox` segments + discs at vertices to round the bends, footpaths lighter, thinner and a hair above the carriageways (anti z-fighting), no cast shadows. Cap of 200 roads.
- Generalized model `SunRoadNeighborhood { buildings, roads }`: disk cache v2 (suffix `_v2` — an old v1 cache is simply re-downloaded), HUD "n bâtiment(s) · m route(s)" (n building(s) · m road(s)). Enriched parser tests (2-point roads accepted, width profiles, pedestrian).

## 2026-08-10 (v2.0 Phase B — OSM neighborhood in SunRoad + renaming)

### Changed
- **Renaming Helios → SunRoad** (Vincent's request): `Sources/Helios/` → `Sources/SunRoad/`, types `SunRoadGeometry`/`SunRoadSceneView`/`SunRoadView`, window `id "sunroad"` titled "SunRoad", header button "SunRoad (3D)", tests renamed.

### Added
- **Phase B — the neighborhood in 3D** (branch `feat/helios-scene`):
  - `GeoProjection`: pure equirectangular lat/lon → meters (east, north) projection, centroid and distance of a footprint — 3 tests.
  - `OverpassService` + `OverpassParser`: `way["building"]` footprints within a 120 m radius via the public Overpass API (`out geom`), heights from `height` (tolerates "7.5 m", comma) or `building:levels` × 3 m (default 6 m, cap 60 m), sorted by distance and capped at 250 buildings — pure parser, 3 tests. `SunRoadCache`: JSON per rounded location (1e-4°) in Application Support — buildings don't move, a single fetch.
  - Scene extended to the neighborhood (140 m dome, camera pulled back): extruded buildings (`SCNShape` flipped to the ground, (east, north, height) → (x, y, -z)), **the house = the building closest to the configured position (< 25 m), highlighted amber**, placeholder hidden as soon as OSM answers; neighbors cast their **real shadows** on the scene — the heart of the Helios effect.
  - HUD: loading state ("n bâtiment(s) du quartier", soft error without network — the scene remains usable) + "Recharger le quartier" (Reload the neighborhood) button.
  - 108 tests green, build with no warnings.

## 2026-08-10 (v2.0 Phase A — Helios 3D foundation)

### Added
- **"Hélios" window** (indigo `cube.transparent` button, `Window id "helios"`) — Phase A of the v2.0 plan (PLAN.md Phase 13, validated decisions: number 2.0, SceneKit rendering):
  - `Sources/Helios/HeliosGeometry.swift`: pure azimuth/elevation → SceneKit 3D frame mapping (Y up, north = -Z, east = +X), array surface from its peak power (~200 Wp/m², bounded 1–40 m²), day/night brightness ramp (-6° → +15°). 4 unit tests.
  - `Sources/Helios/HeliosSceneView.swift`: SceneKit scene — ground, compass ring with cardinals, placeholder house (walls + roof, replaced by OSM in phase B), panel arrays as tilted planes (real azimuth/tilt from the Sun window), the day's sun arc (SunCalc.track 10 min step, cylindrical segments + hour markers), sun = emissive sphere + **directional light with real cast shadows** (2048 shadow map), sky and intensities interpolated night/twilight/day, native orbital camera (orbitTurntable). Arc and panels rebuilt only when day/place/arrays change.
  - `Sources/Helios/HeliosView.swift`: HUD (date-time, elevation, azimuth, sunrise–sunset), 60 s clock, "not configured" screen pointing to the Sun window (same `sunLatitude`/`sunLongitude`/`sunArrays` settings).
- Prior merge of `fix/sleep-wake-recovery` into main (`1aba549`) after Vincent validated the lid test — release 1.12.1 not yet decided. 102 tests green, build with no warnings. Branch `feat/helios-scene`.

## 2026-08-10 (recovery after sleep + History debug checkbox)

### Fixed
- **Cloud mode dead after a sleep** (lid closed → "no data" until a manual re-click on Cloud Zendure). Root cause: on wake, the reconnection relaunched `CloudService.start()` while Wi-Fi was not yet back up; the HTTP failure of the deviceList set `.failed` **without rescheduling a retry** — a definitive dead end. Three parts:
  - `CloudService`: new `scheduleRetry(message:)`, common path for MQTT drops and deviceList HTTP failures — any error reschedules a full `start()` 15 s later (an invalid Cloud Key remains a clean failure with no retry, it is deterministic).
  - `MQTTClient`: **timeout on the PINGRESP** (`awaitingPingResponse`) — after a sleep, the socket can be half-dead (no error reported, no more traffic) and the session stayed "live" on an empty stream; now a PINGREQ without a response at the next cycle (~30 s) cuts the connection, which triggers reconnection. Any incoming packet rearms the flag.
  - `Monitor`: `NSWorkspace.didWakeNotification` observer — 3 s after wake (time for Wi-Fi to reattach), clean restart of the cloud session (if Cloud mode) and of the poll cycle, without waiting for the keepalive timeout.

### Changed
- **History window**: the Debug card is now hidden by default, behind a "Afficher le débogage (échanges HTTP)" (Show debug (HTTP exchanges)) checkbox (`historyShowDebug`, persisted).

## 2026-08-10 (landing + guide for 1.12)

### Docs
- **Landing** (`docs/index.html`): new "📈 History window" card in the Features grid (365 days from the Zendure servers, per-device metrics, lifetime totals, local cache, Keychain credentials, local and cloud modes).
- **Guide**: new pages `fr/historique.md` and `en/history.md` (opening via the purple clock, login with the main account — the Cloud Key is not enough, window content, cache and request spacing, Debug card, non-contractual API warning); FR/EN tables of contents renumbered (History at position 6); sun ↔ history ↔ widgets navigation rewired (check: 0 broken internal links); panel pages: the header goes to "five actions" with the purple clock row. Branch `docs/1.12-landing-guide` (`9d56a1c`) merged into main (`a0d93ce`), pushed — Pages redeploys automatically.

## 2026-08-10 (release v1.12.0)

### Added
- **Release v1.12.0 (build 19)**: History window. Branch `feature/history-module` merged `--no-ff` into main, bump via `release/1.12.0` (`9a6d404`, merge `8a3d6b8`), 3.9 MB DMG notarized (Accepted) + stapled + Sparkle-signed, GitHub release `v1.12.0` created before the appcast push (`86084a6` with README "New in 1.12" + roadmap — v1.12 checked, remainder moved to v1.13), asset verified HTTP 200. Installed from the DMG in /Applications (lsregister procedure, build 19 confirmed), independent checks OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), relaunched, local poll verified (fresh widget-snapshot). Merged branches deleted.

## 2026-08-10 (History module — ported from ZendureCloud)

### Added
- **"Historique" (History) window** (purple `clock.arrow.circlepath` button in the panel header): energy per day as bars (kWh) over 7/30/90/365 days per device, metric selector (solar, home, battery charge/discharge… — union of the keys actually returned), lifetime totals, progress banner and HTTP debug card (password masked). Module ported from the exploratory ZendureCloud app.
- **`Sources/Cloud/ZendureAppAPI.swift`**: client of the Zendure mobile app's private API — the only known path to history (tdengine endpoints). Email/password login → Blade-Auth token, regional base taken from the Cloud Key if configured (otherwise EU). Static, pure request builders, testable without network.
- **`Sources/Cloud/EnergyHistory.swift`**: `EnergyDay` (raw key → value fields, their list varies by product), catalog of FR metric labels, per-device JSON disk cache (`Application Support/ZendureMonitor/history`) — past days are immutable, only "today" is re-downloaded.
- **`Sources/Cloud/HistoryService.swift`**: orchestration (ObservableObject) — credentials in the Keychain (`appAccount`/`appPassword`, a path totally separate from the Cloud Key), standalone device list (that of the app account: history works in local mode as in cloud mode, with no reconciliation), throttled sequential retrieval (150 ms), log of the last 50 HTTP exchanges.
- 12 unit tests ported (`Tests/ZendureAppAPITests.swift`): login/energy request shape, parsers, password redaction, dates. 98 tests green, build with no warnings. Branch `feature/history-module`, neither merged nor released.
- **Test build installed** in /Applications: Developer ID-signed Release (Hardened Runtime, no notarization or DMG), lsregister procedure + detached relaunch; local poll verified (fresh widget-snapshot) — the stable signature preserves the local-network TCC grant, unlike an ad hoc Debug.

### Changed
- **Metrics per source** (test feedback): the metric selector is moved into each device card and lists only the fields actually returned by that source (the list varies by product — Hub 2000: 4 fields, Hyper: 5…); choice remembered per device (fallback to "solar" if the key no longer exists). The global selector — a misleading union of all devices' keys — disappears from the controls.

## 2026-08-10 (release v1.11.1)

### Added
- **Release v1.11.1 (build 18)**: cloud MQTT diagnostic patch. Branch `fix/cloud-mqtt-diagnostics` (`9ae8bae`) merged `--no-ff` into main, bump via `release/1.11.1` (`4a7fb0e`, merge `c8d5c2c`), 3.7 MB DMG notarized (Accepted) + stapled + Sparkle-signed, GitHub release `v1.11.1` created before the appcast push (`2d29c7f`), asset verified HTTP 200. Installed in /Applications (lsregister procedure, build 18 confirmed), independent checks OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), relaunched. v1.11.1 roadmap line in the README; release notes with the advice "only one integration per Cloud Key".

## 2026-08-10 (cloud MQTT diagnostic patch — user report with 2 SolarFlow)

### Fixed
- **Diagnosis of the "MQTT connection lost: connection closed by the server" loop** (report from a user with two SolarFlow units, exact cause not confirmed — three hypotheses instrumented):
  - `MQTTClient` parses the **SUBACK return codes** (`.suback(returnCodes:)`, body = packetId + one code/topic) and cuts with "abonnements refusés par le serveur" (subscriptions refused by the server) if all are 0x80 — previously, a subscription refusal left the session "live" on an empty stream.
  - `CloudService` detects the **session takeover loop**: ≥ 3 consecutive server closures < 10 s after a successful connection → dedicated message explaining that the Zendure cloud accepts only one real-time session per Cloud Key (Home Assistant, ioBroker, the app on another Mac…). Fields `lastConnectAt`/`rapidDropCount`, only touched from the MQTT callbacks (serial queue).
  - The **deviceList filters out entries with empty `deviceKey`/`productKey`** before subscriptions and getAll — a malformed topic (`iot//…/#`) can cause an ACL closure on EMQX.
- 2 SUBACK tests added (codes carried, body without codes ≠ refusal). All tests green. Not committed, not released.

## 2026-08-10 (landing + guide for 1.11)

### Docs
- **Landing `docs/index.html`**: card "The full panel" (total consumption, card collapse, hiding), card "Cloud mode & Smart CT" and section "Three connection paths" (1.11 automatic switch, new dedicated ✓ point in the summary panel).
- **Guide FR/EN**: panel page — **Home consumption** card documented (missing since 1.10.3, with the three Smart CT states), "five cards", 1.11 collapse and "Panel cards" section of settings; cloud page — section "Automatic switching (new in 1.11)"; remote access page — note "What if the VPN goes down?" pointing to the auto switch.
- Branch `docs/1.11-landing-guide` (`87fbed4`) merged into main (`1cf6d21`), pushed — GitHub Pages deployment verified ("Deploy GitHub Pages" workflow ok). 1.11.0 installation reconfirmed on the Mac (build 17 active).

## 2026-08-10 (release v1.11.0)

### Added
- **Release v1.11.0 (build 17)**: automatic local ⇄ cloud switch + collapsible/disableable cards. Single commit `afc7e29` on `feat/auto-switch-and-collapsible-cards` merged `--no-ff` into main, bump via `release/1.11.0` (`bfcac6a`, merge `b5bccf5`), 3.7 MB DMG notarized (Accepted) + stapled + Sparkle-signed, GitHub release `v1.11.0` created before the appcast push (`2b5a3b3`), asset verified HTTP 200. Installed in /Applications (lsregister procedure, build 17 confirmed), independent checks OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), relaunched.

### Docs
- **README**: "New in 1.11" paragraph + roadmap v1.11 checked, remainder (outputPower, zenSDK error fields, Chinese localization, reorderable cards, widget button, CT draw history) moved to v1.12; release notes `release/release-notes-1.11.0.md`; TODOS aligned.

## 2026-08-10 (collapsible and disableable panel cards)

### Added
- **Collapsible cards in the panel** (Vincent's request, Juicy style): `MetricCard` gains `collapseKey` (state persisted in UserDefaults) and `collapsedSummary` — one click on the header collapses/expands (animated chevron, 0.18 s), and the collapsed card shows only its header + a key value (solar W, battery %, home flow W, home consumption W, history total kWh). Existing uses of MetricCard (dashboard, Sun) remain non-collapsible (backward-compatible init, optional parameters).
- **Configurable card visibility**: new section Settings → Display → "Cartes du panneau" (Panel cards), 5 toggles (`showSolarCard`, `showBatteryCard`, `showFlowsCard`, `showConsumptionCard`, `showHistoryCard`, default visible) read by @AppStorage in MenuView. Build + tests OK. Not committed, not released (waiting with the local ⇄ cloud auto switch).

## 2026-08-10 (automatic local ⇄ cloud switch)

### Added
- **"Basculer automatiquement" (Switch automatically) option** (Settings → Data source, key `autoSwitchMode` — Vincent's request from the [région], [Mac-collecteur] offline): in local mode, after **2 consecutive failed polls** (main AND fallback host) and if a Cloud Key is registered, the app switches to Cloud mode by itself; in Cloud mode, a **probe of the local host every 60 s** (5 s timeout) brings it back to local as soon as the SolarFlow responds. The panel footer shows "Connexion : Cloud Zendure — bascule auto" (Connection: Zendure Cloud — auto switch) when Cloud mode results from a switch (`Monitor.autoSwitchedToCloud`, not persisted — cosmetic). New members: `autoSwitchMode` (persisted), `localFailureStreak`, `lastLocalProbe`, `autoSwitchBackIfLocalReachable()`. Build + tests OK. Not committed, not released.

## 2026-08-10 (release v1.10.4)

### Added
- **Release v1.10.4 (build 16)**: distinct state for the unreachable Smart CT. Feature branch `feat/smart-ct-unreachable-state` (`81d7b69`) merged `--no-ff` into main, bump via `release/1.10.4` (`7fee1b1`, merge `dbd3ad6`), 3.6 MB DMG notarized (Accepted) + stapled + Sparkle-signed, GitHub release `v1.10.4` created before the appcast push (`d4113f5`), asset verified HTTP 200. Installed in /Applications (lsregister procedure, build 16 confirmed in the Launch Services dump), independent checks OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), local poll verified after relaunch.

### Docs
- **README**: 1.10.4 sentence added to the "New in 1.10.3" paragraph + roadmap line v1.10.4 checked; release notes `release/release-notes-1.10.4.md`.

## 2026-08-10 (unreachable Smart CT: distinct state in the UI)

### Changed
- **The interface now distinguishes three Smart CT states** (Vincent's request: in remote Cloud mode, the card suggested that no meter was configured): measured → total consumption; **configured but unreachable** (the CT is only readable from the local network, never relayed by the cloud) → Home consumption card in "via SolarFlow seulement" (via SolarFlow only) with a `wifi.slash` message explaining that the grid draw is not counted and that the value is partial; not configured → invitation to fill in the CT (message unchanged). Dashboard flow diagram legend adapted the same way. New helper `Monitor.ctConfigured` (CT host filled in). Debug build OK. Not committed, not released.

## 2026-08-09 night (release v1.10.3)

### Added
- **Release v1.10.3 (build 15)**: "Consommation maison" (Home consumption) card in the panel. Feature branch `feat/menu-home-consumption` (`e657c39`) merged `--no-ff` into main, bump via `release/1.10.3` (`e41fc39`, merge `78aa010`), 3.6 MB DMG notarized (Accepted, ID `24943509`) + stapled + Sparkle-signed, GitHub release `v1.10.3` created before the appcast push (`c2a2e66`), asset verified HTTP 200. Installed in /Applications (lsregister procedure, build 15 confirmed in the Launch Services dump), independent checks OK (spctl Notarized Developer ID, codesign --deep --strict, stapler validate), local poll verified after relaunch.

### Docs
- **README**: "New in 1.10.3" paragraph (Home consumption card) + roadmap line v1.10.3 checked; release notes `release/release-notes-1.10.3.md`.

## 2026-08-09 night (Home consumption card in the panel)

### Added
- **"Consommation maison" card in the menu bar panel** (`MenuView.consumptionCard`, between Flows and History — Vincent's request): with a configured Smart CT, shows the home's total consumption (grid draw excluding the SolarFlow's AC charging + SolarFlow feed-in) with the per-source detail (LegendRow "Depuis le SolarFlow" (From the SolarFlow) / "Depuis le réseau" (From the grid)); without a CT, shows the SolarFlow feed-in alone with an invitation to fill in the Smart CT in Settings → Network.

### Changed
- **Home consumption calculation centralized in `EnergyMath`** (`gridToHome(ctTotal:gridIn:)` and `homeTotal(ctTotal:gridIn:outputHome:)`); `EnergyFlowView` refactored to use these helpers instead of its local calculation. Debug build OK.

## 2026-08-09 night (release v1.10.2 + dashboard screenshot)

### Added
- **Release v1.10.2 (build 14)**: symmetric X layout of the flow diagram. Merges into main (`50f48b8` layout, `e02577f` bump), 3.6 MB DMG notarized (Accepted) + stapled + Sparkle-signed, GitHub release `v1.10.2` created before the appcast push (`56d5a8e`), asset verified HTTP 200, release notes committed (`910accc`). Installed in /Applications (lsregister procedure), independent checks OK (spctl Notarized Developer ID), local poll verified after relaunch.

### Docs
- **`docs/dashboard.png` regenerated** (merged `dae8967`): 1640×1958, light theme, symmetric X with measured Smart CT (vertical Grid → Home link 455 W, total consumption 835 W), same synthetic data as the 1.10 screenshot. Harness rebuilt (bare CLI, real Monitor: poll neutralized with empty host + notifications disabled before init, WindowPolicy/Updater stubs, opaque background). Pitfalls noted: the 1st poll cycle clears `ctReport`/`lastError` (re-inject after ~1.5 s); the dashboard view is vertically elastic → fixed height 979 pts (fittingSize underestimates it, sizeThatFits returns the proposed height).

## 2026-08-09 night (flow diagram: symmetric X)

### Changed
- **Symmetric X layout of the flow diagram** (branch `feat/energy-flow-mirror-layout`, commit 8e33fd3 — Vincent's request): Panels (top) and Batteries (bottom) move to the left column, an exact mirror of Home (top) and Public grid (bottom) on the right, SolarFlow in the center; the off-grid socket now hangs below the hub. The diagram remains planar — no flow crossing. Tests green, rendering verified via the harness (light/dark × CT present/absent × socket active). Not merged, not released.

## 2026-08-09 night (release v1.10.1)

### Added
- **Release v1.10.1 (build 13)**: Bonjour → IP discovery fix (`13f2257`) + planar flow diagram (`f6594e6`). `--no-ff` merges into main (`d72746f` diagram, `2bb272f` bump), push, 3.6 MB DMG notarized (Accepted, ID `f0abff0f`) + stapled + Sparkle EdDSA-signed, GitHub release `v1.10.1` created before the appcast push (`1e5293f`), enclosure verified HTTP 200.
- Installed in /Applications (full lsregister procedure), independent checks: `spctl` → Notarized Developer ID, `codesign --deep --strict` OK, `stapler validate` OK, local poll verified after relaunch (fresh `widget-snapshot.json`).
- `build/` recreated by release.sh purged afterwards (no residual concurrent copy); branches `fix/energy-flow-no-crossing` and `release/1.10.1` deleted after merge.

### Notes
- Remaining: regenerate `docs/dashboard.png` (the flow diagram changed layout).

## 2026-08-09 evening (flow diagram: no more crossings)

### Changed
- **Planar energy flow diagram** (branch `fix/energy-flow-no-crossing`, commit f6594e6): the Grid → Home arc passed under the hub and crossed the vertical hub → batteries link. Public grid and Home are now **adjacent in the right column** (Home on top, Grid below — the meter is physically between the two): their direct link is a vertical segment along the edge, out of the path of all other flows. Off-grid socket moved to the bottom-left corner; central column (Panels/SolarFlow/Batteries) shifted to x = 0.42 for balance.
- `node()`: explicit label placement (`LabelPlacement`: below / above / titleAbove) — Home's texts go above its pad to leave the vertical link clear.
- The quadratic arc `gridToHomeArc` disappears: the measured case (Smart CT) goes through `link()` like any real flow, the unmeasured case through `unmeasuredLink()` (gray segment + "? non mesuré" capsule).
- Dashboard note: "gray arc" → "gray link".
- Verified: build OK, 85/85 tests, real rendering via NSHostingView harness (light/dark × CT present/absent × socket active) — no crossing in the 4 screenshots.

## 2026-08-09 evening (resolution of the "local mode KO, cloud OK" incident — multiple versions)

### Fixed
- **Local mode working again.** Review of the local path (Discovery, fetchReport/fetchWithFallback, ATS `NSAllowsLocalNetworking`, entitlements): no bug — the SolarFlow answered in 40 ms to `curl`. Actual cause: an **ad hoc-signed Debug instance launched from DerivedData** was running in place of the installed app; each ad hoc rebuild changes the code designation, macOS then silently invalidates the "local network" TCC grant (cloud mode, outgoing Internet traffic, is not subject to this grant — hence the asymmetric symptom).
- Version cleanup: instances quit, **1.10.0 installed in /Applications** from the notarized DMG (spctl: Notarized Developer ID), `lsregister -f` + `killall Dock`, Launch Services deregistration of the 4 ghost copies (build/Debug, build/Release, DerivedData, iCloud trash), purge of `build/` and DerivedData, trash copy deleted.
- Verified: app relaunched, `widget-snapshot.json` rewritten with fresh SolarFlow data (local poll OK, IP [IP-SolarFlow-1]).

### Notes
- The 1.10.0 DMG (13:07) predates the Bonjour→IP fix merge (13:36): the installed app still discovers by `.local` name (slow). Non-blocking (hard-coded IP in settings); v1.10.1 to be cut.

## 2026-08-09 (fix: unusable .local hosts — discovery returns the IP)

### Fixed
- **"Detected but impossible to test/use"**: getaddrinfo resolution of `.local` names takes ~5 s on Vincent's network (silent AAAA query) — right above the app's `timeoutIntervalForRequest = 5`, while the same call by IP answers in 40 ms and the mDNS resolution of the address is instantaneous (`dns-sd -G` immediate). Bonjour discovery now returns the **resolved IPv4 address** (already present in `NetService.addresses`) instead of the host name, with fallback to the name if there is no IPv4. `sockaddr_in` parsing extracted into `DeviceDiscovery.ipv4Address(from:)`, tested (IPv6 ignored, truncated data ignored).
- Vincent's settings switched to IPs: SolarFlow `[IP-SolarFlow-1]`, Smart CT `[IP-SmartCT-ancienne]` (the CT poll also failed by timeout via `.local`).

### Notes
- The SolarFlow only advertises under `_http._tcp` (name `Zendure-solarFlow2400Pro-<SN>`), the Smart CT under `_zendure._tcp` — both types remain necessary in the browser.
- Known limitation: an IP may change at DHCP lease renewal — if that happens, rerun "Rechercher sur le réseau". The `.local` name remains usable manually for those who prefer it.

## 2026-08-09 (landing: the 3 connection modes)

### Docs
- **Landing "Local-first" section rewritten as "Three connection paths — your choice"** (merged `a6fad94`): three cards — Local (main host, the recommended default), Local via VPN (fallback host, automatic switch), Zendure Cloud (optional, real-time MQTT, read-only) — with the panel's connection footer as a common thread; technical panel refocused (local mode by default without a Zendure server, Bonjour discovery, Smart CT always read locally) and security warning kept.

## 2026-08-09 (1.10 screenshots)

### Docs
- **panel-light/panel-dark/dashboard regenerated** (branch `chore/screenshots-1.10`, merged `bca52fc`): connection footer in the panel, diamond flow diagram with the measured Smart CT arc (455 W) and total home consumption (835 W) in the dashboard. Synthetic data consistent with the 1.9 screenshots (612 W, 75%, fake SN).

### Decisions
- Rendering harness: NSHostingView + off-screen NSWindow + `cacheDisplay` — **opaque background mandatory at the root**: without it, texts in semantic colors outside cards (header, footer) go through the vibrancy layer that `cacheDisplay` does not capture (header/footer invisible, black background). Notifications disabled in the harness defaults → no need for an .app bundle (UserNotifications never touched).

## 2026-08-09 (release 1.10.0)

### Added
- **Release 1.10.0** (build 12): Zendure Cloud mode (read-only, Cloud Key in the keychain, real-time MQTT), Smart CT support (real grid draw + total home consumption, local poll), redesigned flow diagram (aligned diamond, measured/"non mesuré" Grid → Home arc), connection footer in the panel, Settings → Network tab.

### Docs
- README: intro "local-first + optional Cloud mode", "New in 1.10" paragraph, technical section "The optional Cloud mode" (+ renumbering), layout (`Sources/Cloud/`, `SmartCT.swift`), roadmap (v1.10 checked with the real content, carry-overs to v1.11).
- Landing: tagline and "Local-first" section, card "☁️ Cloud mode & Smart CT", rewritten diagram card, dashboard figcaption.
- Guide: new page `fr/cloud.md` + `en/cloud.md` (Cloud mode step by step, Smart CT), guide index at 11 entries, updated bilingual intro.
- `release/release-notes-1.10.0.md`.

### Decisions
- Merge: `--no-ff` merge of `feat/cloud-mode` into `main` (`c321637`), pushed before the release; appcast published after the creation of the GitHub release (1.9.0 lesson: avoid the Sparkle 404).
- The screenshots (panel/dashboard) date from 1.9 — regeneration noted as a TODO (the new diagram and the connection footer don't appear in them yet).

## 2026-08-09 (Settings reorganization — branch `feat/cloud-mode`)

### Changed
- **"Distant" tab → "Réseau" (Network)**, which now groups in three short sections the Smart CT meter (moved from Device), the fallback host and the 24/7 history server — the Device tab now only carries the data source (Local/Cloud) and the refresh.
- **Shortened help texts** (Cloud Key, Smart CT, remote access, collector): same essential information, much shorter sections; the dashboard note points to Settings → Network.

## 2026-08-09 (panel footer: connection mode — branch `feat/cloud-mode`)

### Added
- **Permanent footer of the menu bar panel**: icon + "Connexion : locale — hôte principal" (Connection: local — main host), "locale — hôte de secours" (local — fallback host) or "Cloud Zendure", with a green dot (last cycle succeeded) or orange (in error), separated by a `Divider`.

### Removed
- One-off banner "Connecté via l'hôte de secours" (Connected via the fallback host) (redundant with the footer) + its translation key.

## 2026-08-09 (Smart CT integrated — branch `feat/cloud-mode`)

### Added
- **Smart CT discovery**: Vincent's SmartMeter3CT is indeed paired (visible in the Zendure app) but absent from the "HA" `deviceList` and silent on the account's MQTT broker (verified: 180 s probe with `#`/`iot/#`/`/+/+/#` wildcard subscriptions — only the SolarFlow's topics get through, raw deviceList response dumped). However it **advertises over Bonjour** (`_zendure._tcp`, `Zendure-smartMeter3CT-[SN-CT]`) and its **local zenSDK API answers**: `GET /properties/report` → `{a/b/c_aprt_power, total_power}` (real reading: 2089 W on phase C).
- **`Sources/SmartCT.swift`**: `CTReport` + `SmartCTParser` (flat payload, total or sum of phases, tolerant of Int/Double/String) — 3 tests in `Tests/SmartCTTests.swift` with the real payload.
- **`Monitor`**: `ctHost` setting (persisted), CT poll at every cycle **in both modes and even when the SolarFlow does not respond** (the CT is a distinct device); failure → `ctReport = nil` so as never to display a frozen measurement as a real flow.
- **Flow diagram**: when the CT responds, the Grid → Home arc becomes a **real measured flow** (orange, animated, power = `total_power - gridInputPower`) and the Home node shows the **total consumption** (grid + SolarFlow feed-in); without a CT, back to the gray "not measured" arc. Note under the card with the per-phase detail.
- **Settings → Device → "Compteur Smart CT (optionnel)" (Smart CT meter (optional))**: host field, "Détecter sur le réseau" (Detect on the network) button (Bonjour, smartMeter/3CT filter), "Tester" (Test) button; `ctHost` preconfigured on Vincent's installation via `defaults write`.

### Notes
- The Zendure cloud does not relay the CT's measurements: away from home (Cloud mode without LAN), the arc honestly goes back to "not measured".
- Indirect confirmation of CT control in the cloud stream: `mode: 12` (smart matching) and `outputLimit` setpoint continuously readjusted (1536→1595 W) by the CT.

## 2026-08-09 (energy flow diagram redesign — branch `feat/cloud-mode`)

### Changed
- **`EnergyFlowView` redrawn as a strictly aligned diamond**: Panels at the top, SolarFlow in the center, Batteries exactly below the hub (the alignment defect came from a `.position()` applied to a composite HStack — pads are now anchored by their center, labels positioned separately), Public grid on the left, Home on the right. Pulsing halos on active nodes, same animated language as the Sun window (`SkyDomeView`).
- **Gray "not measured" Grid → Home arc**: the flow exists electrically but is measured by no one without a panel meter (Smart CT) — it is drawn explicitly ("? non mesuré" capsule) instead of being omitted, and a note under the card explains that the home's total consumption is unknown. The Home node carries the mention "+ réseau : non mesuré".
- Per-pack SOC pads under the aggregate gauge; battery flow value in the label (▲/▼) rather than in a capsule on the short link; the off-grid socket appears only when it is delivering; the PV value lives in the link's capsule ("Panneaux" label above the pad).

### Notes
- Verified in real rendering (throwaway `ImageRenderer` harness, light/dark × calm/loaded scenario, data from the cloud probe) — in line with the rule "a view that compiles is not a view that works". 3 FR→EN strings added.

## 2026-08-09 (Cloud mode — branch `feat/cloud-mode`, not merged)

### Added
- **Zendure Cloud mode** in addition to the local API mode (protocol taken from the project validated live `~/DevApps/Experimentations/ZendureCloud`): Cloud Key Authorization (base64 → apiUrl + appKey, split at the last dot) → SHA1-signed `POST /api/ha/deviceList` → MQTT credentials → subscription `/{pk}/{dk}/#` + `iot/{pk}/{dk}/#`, merge of partial reports, 60 s `getAll` fallback poll.
- **`Sources/Cloud/`** (zero external dependencies): `CloudKey`, `CloudModels` (ZendureDevice, MQTTCredentials host:port), `ZendureAPI`, `MQTTClient`/`MQTTPacket` (in-house MQTT 3.1.1 over Network.framework), `CloudDeviceState` (merge + unit conversions + mapping to the local `DeviceState`), `CloudService` (orchestration, 15 s reconnection by full re-login, getAll timer on a separate queue — deadlock pitfall documented), `KeychainHelper` (Cloud Key in the keychain, service `fr.lauriat.ZendureMonitor`, never UserDefaults).
- **Settings → Device**: "Source des données" (Data source) Picker (Local API / Zendure Cloud), Cloud section (SecureField, "Tester la clé" (Test the key), phase status, tracked device if the account has several — key `cloudDeviceKey`).
- **`Scripts/cloud-probe.swift`**: CLI probe that lists the account's devices then dumps all MQTT topics/keys received — to check what the cloud really publishes (e.g. overall home consumption / grid draw via Smart CT).
- **`Tests/CloudTests.swift`** (20 tests ported from ZendureCloud): Cloud Key decoding, deviceList signature/headers, MQTT packets, partial report merge, unit conversions, `DeviceState` mapping, host:port.

### Changed
- `Monitor`: **pull** adapter — the existing poll loop reads a merged snapshot in cloud mode (`cloudSnapshot()`, error if missing/stale > 180 s), so that lastError, watchdog, isStale, notifications and widget work identically. Accumulator `maxDt` widened to 180 s in cloud (samples dated from the last MQTT report). `localNetworkDenied` neutralized in cloud.
- `ZendureError`: cloud cases added (`noCloudKey`, `cloudWaiting`, `cloudStale`, `cloudUnavailable`, `cloudReadOnly`).
- Control tab disabled in Cloud mode (read-only — MQTT `properties/write` never validated live); fallback host hidden in cloud.
- `project.yml`: pure cloud sources added to the test target; 33 FR→EN strings added to the String Catalog (compact file format preserved).

### Decisions
- **Single-device kept** (Picker if several cloud devices); **pull rather than stream** (the loop and the watchdog survive as is); **read-only cloud v1**; **`minSoc` auto-scale with threshold 50** (the firmware sends tenths: 100 = 10%, but 20 = 20% directly is still accepted).

## 2026-08-09 (1.9.0 installation + repo housekeeping)

### Changed
- **1.9.0 installed in `/Applications`** from the notarized DMG (the app not being launched, Sparkle had not been able to offer anything). `spctl` on the installed app: `accepted, source=Notarized Developer ID`.
- **Launch Services repair**: `lsregister -f` + Dock restart. Verified in the dump: `/Applications/ZendureMonitor.app` is registered as `version: 11.0` (so the new build, plus the old one).
- **Repo reduced to `main`**: 5 remote and 5 local branches deleted, after verifying that `git branch --no-merged main` is empty locally **and** remotely — no commit existed outside `main`. The 11 version tags (v1.0.0 → v1.9.0) are intact.

### Notes
- Several remote references believed alive (`release/1.1.0`, `chore/post-release`, `feat/app-icon`…) were already deleted on the GitHub side: they were only stale local refs, cleaned by `fetch --prune`.
- The Launch Services database keeps competing records of the app: a 1.6.0 copy in the iCloud trash, and the development builds 1.7.0 (`build/`) and 1.8.0 (DerivedData). No effect on `/Applications`, but they are so many launch candidates — the trash copy deserves to be emptied.
- **The SolarFlow is still absent from the network** (incident of 2026-08-07, unresolved): the mDNS name does not resolve and a 6 s Bonjour sweep sees no Zendure service, whereas mDNS otherwise works from this Mac. The app's "local network" authorization therefore cannot be tested end to end until the device is back.

## 2026-08-09 (release 1.9.0)

### Released
- **v1.9.0** — Sun window v3. `MARKETING_VERSION` 1.8.0 → 1.9.0, `CURRENT_PROJECT_VERSION` 10 → 11 (it is this build number that Sparkle compares, not the marketing version). Developer ID-signed, notarized, stapled, EdDSA-signed-for-Sparkle DMG (3.47 MB). GitHub release `v1.9.0` + appcast published.
- Release notes `release/release-notes-1.9.0.md`: per-array orientations, sky dome, compass, live adjustment, enriched ephemeris, single screen; and the two visible fixes (west facade announcing 323 W at sunset → 30 W, loss of the peak power when deleting the last array).

### Changed
- README: Sun window v3 goes from "merged, awaiting release" to "New in 1.9"; v1.9 roadmap checked, the remaining items shift to v1.10.
- Landing: the Sun card now carries the "Rebuilt in 1.9" mention (it had lost any version marker by changing content).

### Verified
- **Independent verification of the DMG**, without trusting the script's ✅: `spctl -a -t exec -vv` → `accepted, source=Notarized Developer ID`, `codesign --verify --deep --strict` OK, `stapler validate` OK, version 1.9.0 in the mounted bundle.
- **App and widget agree** on 1.9.0 / build 11 — a version mismatch between the app and its extension only shows at notarization, five minutes later.
- **Publication order chosen to avoid any Sparkle 404**: bump + docs pushed, GitHub release created with the DMG, `<enclosure>` URL verified at HTTP 200 (3,466,768 bytes), *then* appcast pushed. Since the appcast is served from `raw.githubusercontent.com/.../main`, the reverse order (the one suggested by the script's "next steps") would expose clients to a nonexistent download URL.
- Appcast re-read online: `sparkle:version` 11 > 10 installed, EdDSA signature and length present.

### Decisions
- The app installed as 1.8.0 is **not** replaced by hand: the update goes through Sparkle. An `rm -rf` + `ditto` in `/Applications` breaks the Finder icon and the local network authorization (see memory `lsregister-after-app-replace`).

## 2026-08-08 (Sun window v3 merge into main + landing/README)

### Docs
- **Landing (`docs/index.html`)**: the "Sun window" card describes the sky dome, the solar compass and the orientation markers instead of the ephemeris alone; the figure goes from `max-width:520px` to `900px` (the screenshot is now 1800×1224 landscape, it was displayed squashed) with an updated `alt` and caption.
- **README**: Sun window v3 is announced as merged into `main` awaiting release (and no longer "next up"), with the azimuth/tilt sliders and the single screen; project layout mentions `SolarGeometry` and the real role of `SunView`; v1.9 roadmap updated.
- **Guide index**: the two entries "fenêtre Soleil" / "Sun window" still listed only the ephemeris.

### Verified
- Tag balance of `docs/index.html` checked with a parser before commit (no unclosed tag).
- `--no-ff` merge into `main` (20 files, +2586/−240), pushed as `91575b5`. CI and Pages deployment triggered.

## 2026-08-08 (Sun window: direct orientation adjustment + everything on one screen, branch feat/sun-panel-orientations)

### Added
- **Azimuth and tilt sliders in the "Champs de panneaux" (Panel arrays) card** of the Sun window: an array is reoriented without going through settings, and the dome, compass, incidence and yield follow the gesture. Immediate write to the shared storage, so settings display the same value.
- Tooltips (`.help`) carrying the long explanation of cards whose caption was shortened.

### Changed
- **Three-band layout**: full-width indicator banner, then dome + compass, then three columns (panel arrays | ephemeris + yield | light + weather). Default window 1400×980 (versus 900×780): the content needs 927 pt out of 952 pt available, so **no more scrolling** — also verified with three panel arrays. The `ScrollView` is kept as a safety net (many arrays, enlarged text, small window).
- The compass follows the dome height instead of leaving a gap under its card.
- An array's row shows the cardinal point and peak power; degrees are read on the sliders.
- 9 localized strings added (FR+EN), 3 that became dead removed — keys verified via `SWIFT_EMIT_LOC_STRINGS` before writing.

### Fixed
- **The first orientation setting of a v1.8 user was lost**: `arrays` rebuilt the legacy array from `sunPeakWatts` at every read, therefore with a new `UUID`, and the identity binding did not find its row. The migrated list is now materialized in the storage when the window opens.

### Verified
- `xcodebuild` OK, **60 tests green**. Off-app renderings reviewed in light, dark and English, with two and three arrays; content height measured by the harness (927 pt < 952 pt).
- New test `testStoreRoundTripsEverySliderStepExactly`: each step of the two sliders (73 azimuths × 7 tilts) goes through the JSON encoding and comes back **bit for bit**. This is the guarantee that the handle does not jitter and lands where it is released — the slider rereads the value from the storage at the next render.
- Cost of a slider drag measured (72 steps): model 0.06 ms/step, storage write 0.2 ms/step, **full redraw 60 ms/step in forced layout** — upper bound, since SwiftUI batches renders during a real drag. To be confirmed by a real drag (Vincent).

## 2026-08-08 (Sun window v3 — panel orientations + animated dome, branch feat/sun-panel-orientations)

### Added
- **`SolarGeometry`** (Sources/Shared, pure Foundation, 12 tests): `PanelArray` (name, Wp, azimuth, tilt), `PanelArrayStore` (JSON in UserDefaults + soft migration of `sunPeakWatts`), incidence cosine, panel-plane factor (85% direct weighted by incidence × Meinel atmospheric transmittance + 15% diffuse according to the visible sky share), per-array clear-sky yield and energy, best hour, 3D iso-incidence contour, air mass, shadow length.
- **`SunCalc` extended** (existing signatures unchanged — `OutageWatchdog` depends on it): `track()` (sampled day course), `crossings(atAltitude:)` and `twilight()` (civil/nautical/astronomical twilight + golden hour), `declination()`, `nextSolarEvent()` (next solstice/equinox by bisection). 4 more tests.
- **`SkyDomeView`**: animated sky dome — gradient sky according to elevation (starry night → golden hour → full day), hour-by-hour day course (traveled portion vivid, rest dimmed), arcs of the two solstices, measured production laid on the azimuth axis, orientation markers with incidence deviation and halo when the array is aligned, sun with pulsing halo and rotating ray crown.
- **`SunCompassView`**: polar compass (center = zenith) with day course, solstices, and real 25°/50° iso-incidence contours around each array's normal.
- **Sun window rewritten**: 5-indicator banner, dome as hero, compass, detailed per-array card (yield, incidence, share of irradiance captured, best hour, day potential), enriched ephemeris (day-length delta to the second, next solstice/equinox), "Lumière et crépuscules" (Light and twilights) card, yield (day energy vs potential, air mass, shadow), weather (explicit cloud factor). Window switched to `ScrollView`, `defaultSize` 900×780 (it was 540×680 while the content demanded 760 in width).
- **Settings → Soleil**: multi-array editor (name, Wp, azimuth with cardinal label, tilt), add/delete, peak total. `sunPeakWatts` stays synchronized with the installed total.
- 74 localized FR/EN strings + 18 English translations that had always been missing on this surface (weather, ephemeris); 9 keys of the old Sun UI removed.

### Fixed
- **Yield model**: a due-west array announced its full power at sunset (323 W at 1.6° elevation) — the atmosphere traversal was missing, it now announces 30 W.
- **Data loss in settings**: deleting all one's arrays overwrote `sunPeakWatts` with 0, irreversibly erasing the peak power entered under v1.8. The key is now only written when the total is non-zero.
- **Array editor layout**: in a grouped `Form`, each row's `VStack` was exploded into separate rows (the name became a label, the sliders ended up orphaned, the `Divider` created an empty row). Rebuilt as one full-width header row + two `LabeledContent` — a defect visible only when rendering the view, not at compilation.
- **`xcodebuild test` failed before running the tests**: the `ZendureMonitorTests` target had no `Info.plist` and therefore could not be signed (`GENERATE_INFOPLIST_FILE: YES` added in `project.yml`).
- Sun course and solstice arcs were drawn in different azimuth frames (independent unwrapping): realigned on a common domain.
- The sun was placed by linear time progression on a decorative semicircle; it is now placed by its real elevation and azimuth.
- Compass: cardinal letters clipped by the frame edge.

### Changed
- "Champs de panneaux" (Panel arrays) section extracted from `SunSettingsTab` to `Sources/Components/PanelArraysSection.swift` (it is the only part of settings carrying real state logic); `SunSettingsTab` goes from `private` to internal so that the guide's capture harness can render it outside the app.
- `SunView` no longer computes the solstice arcs twice per render (dome + compass share the same computation).

### Docs
- `docs/guide/fr/soleil.md` and `docs/guide/en/sun.md` rewritten (dome, compass, panel arrays, light, model); `sun-light.png` and `settings-sun.png` screenshots regenerated (`NSHostingView` harness — the SwiftUI lifecycle really runs, so the weather card is filled, which `ImageRenderer` alone does not allow).
- Behavior of deleting all arrays documented in both guides.

### Verified
- `xcodebuild` OK, **59 tests green** (41 → 59), off-app renderings inspected at 7 h/10 h/13 h/17 h/20 h/23 h, whole window verified in light, dark and English.
- **Settings → Soleil tab actually executed** in the harness (not just compiled): v1.8 migration (1,200 Wp → one due-south array at 30°, persisted as JSON), then deletion of the last array via its trash button → `sunArrays = []` and `sunPeakWatts` kept at 1,200. Not exercised: the "Ajouter un champ" (Add an array) button and the sliders (drawn by SwiftUI with no drivable AppKit view).

## 2026-08-07 (outage alerts — branch feat/outage-alerts, following the SolarFlow incident)

### Added
- **`OutageWatchdog`** (Sources/Shared, pure struct + 8 tests — 40/40 green): detection of "device unreachable for N min" and "zero production+feed-in while the sun is high".
- **"SolarFlow injoignable" (SolarFlow unreachable) notification** (enabled by default, adjustable threshold 5–60 min, default 10) — one per outage episode, rearmed on recovery.
- **"Production solaire anormale" (Abnormal solar production) notification** (enabled by default): device that responds but 0 W produced/fed in for 30 min with sun > 20° (local SunCalc elevation; disabled if position not configured).
- **⚠️ "offline" menu bar icon** when the unreachable threshold is exceeded (instead of the panel's discreet graying alone).
- Settings: "Alertes de panne" (Outage alerts) section in the Notifications tab; 12 localized FR/EN strings (surgical insertion into the catalog, 36 lines).

### Released
- **v1.8.0** (build 10): PR #17 merged (CI green), DMG signed/notarized/stapled (spctl: Notarized Developer ID), GitHub release, Sparkle appcast, installed in /Applications (lsregister + relaunch). README roadmap: v1.8 checked, remainder moved to v1.9.

### Context
Incident 2026-08-07: SolarFlow in fault (battery full, feed-in cut) then totally off the network — the app had no alert for this case. Still waiting for the device to return: dump of the real payload to parse the zenSDK state/error fields (part c).

## 2026-08-06 (release 1.7.0 + documentation + sites)

### Added
- **Release v1.7.0** (build 9): PR #16 merged, DMG signed/notarized/stapled, GitHub release, Sparkle appcast, installed in /Applications (lsregister -f), independent `spctl` verification OK ("Notarized Developer ID").
- **Complete documentation**: bilingual FR+EN user guide in `docs/guide/` (10 pages × 2 languages, screenshots), enriched README, GitHub wiki populated.
- Release notes 1.5.0 and 1.6.0 finally committed in `release/`.

### Fixed
- **GitHub Pages build repaired**: the "legacy" Jekyll builds had been failing since the v1.6.0 commit (the landing page was no longer updating) → `docs/.nojekyll` added, then full switch to an **Actions workflow** (`.github/workflows/pages.yml`, `build_type=workflow`) because the legacy builder remained broken. Root cause finally identified: **partial GitHub outage ("Incident with Actions")** ongoing that day — the Actions deployment was relaunched after resolution.

### Sites
- **lauriat.fr**: Zendure Monitor card moved from "macOS Productivity" to the **Home automation** category (created earlier in the day with Hayward Monitor by another session), `llms.txt` updated for 1.7.0 (Dashboard/Sun windows, weather, large widget) — commit + push + FTP deployment of the 2 files.
- **vincentlauriat.github.io**: ZendureMonitor card description refreshed (animated dashboard, Sun window + weather, 14-day widgets) — push.

## 2026-08-06 (backlog wave 2 — branch feat/todos-wave-2, PR #16)

### Added
- **Large widget (systemLarge)**: solar/battery/home header, sparkline, 14-day histogram in pure SwiftUI (`MiniBars`), total + "today". `WidgetSnapshot.dailyEnergy` optional (backward-compatible). Refresh button (AppIntents) postponed.
- **Sun window weather**: `WeatherService` (Open-Meteo, no key, 30 min cache) — current conditions (WMO code → SF symbol), cloud cover, forecast sunshine, cloud-adjusted yield (Kasten-Czeplak factor) in a "Météo locale" (Local weather) card.

### Changed
- **`DailyAccumulator`** (Sources/Shared): logic of the day's totals extracted from `Monitor` into a pure struct (bounded dt, local midnight rollover, 5 min buckets, peak, solar/stored/grid totals, collector merge) + **8 tests** — 28/28 green. `Monitor.accumulateEnergy` becomes an adapter. Closes the "Monitor tests" item of the backlog.

### Fixed (bis)
- **Cloud factor corrected** (Vincent's report): Kasten–Czeplak exponent 3 → **3.4**; computation extracted into `EnergyMath.cloudFactor` (bounded 0–100%) + 4 tests — 32/32 green (commit `885b5b1`).

### End of session (state at cutoff)
- **PR #16 open** (CI green, 4 commits: large widget, weather, DailyAccumulator, Sun overhaul + cloud fix) — awaiting Vincent's merge, then release 1.7.
- **/Applications = wave 2 build signed manually** (for real testing) — restore 1.6.0 via `release/ZendureMonitor-1.6.0.dmg` if needed, or release 1.7 after merge.
- **[Mac-collecteur] asleep** (Tailscale `rx 0` via relay): no remote access possible — to be woken up/configured with anti-sleep on site (`sudo pmset -a sleep 0 displaysleep 10`). The real wave 2 test (local polling) remains to be done on returning home.

### Changed (bis)
- **Sun window redesigned** (Vincent's request: "you have to scroll and that's not good"): no more ScrollView — wide window (820×540), sun course × production chart as hero, then Ephemeris · Yield · Weather in 3 columns. The SunCard arc (redundant with the hero) disappears from this window; SunCard now only serves the unconfigured state (position invitation).

### Decisions
- Postponed for Vincent's arbitration: HC/HP optimizer (dedicated plan — drives the real battery), 中文, reorderable cards.
- Unsigned Debug copy → unstable local network authorization (two copies with the same bundle ID); diagnosis in progress, possible workaround: install the signed wave 2 build in /Applications to test.

## 2026-08-06 (release v1.6.0)

### Fixed (post-install v1.6.0)
- Back home (Tailscale off): the app no longer saw the SolarFlow on local Wi-Fi and the icon had disappeared from the Finder. Cause: stale LaunchServices registration after the `rm -rf`+`ditto` replacement in /Applications — nehelper no longer applied the "local network" TCC authorization to the new bundle (it worked through Tailscale/utun, this authorization does not apply to the VPN). Neither the Settings toggle nor `killall nehelper` was enough; **`lsregister -f` + app relaunch** fixed everything (polling + icon). Lesson recorded in memory for all future installs.

### Released
- **v1.6.0** (build 8): DMG signed Developer ID, notarized (Accepted, stapled, verified `spctl` → Notarized Developer ID), Sparkle EdDSA-signed. GitHub release `v1.6.0` with notes, `appcast.xml` + bump versioned on main (`94bdacc`), README up to date (`d7c539b`). Notarized version installed in /Applications and relaunched. Content: solar split of the day (panel + dashboard), offline resilience, remembered VPN fallback, polling debounce, local day, colored icons, EnergyMath + 9 tests.

## 2026-08-06

### Decisions
- Branch `fix/code-review-corrections` created, single commit `0608525` (5 fixes + colored icons), pushed to origin. **PR #14 merged into main** (CI green), branch deleted.
- A strict "self-consumption rate" is impossible without a home meter: the hub does not see downstream consumption. Metric chosen instead: production split (direct/stored) + grid total, deduced from the hub flows.

### Added (branch feat/daily-energy-split)
- **Solar split of the day** in the Flows card: "Solaire du jour : X % direct · Y % stocké" (Solar of the day: X% direct · Y% stored) + "Réseau : Z kWh" (Grid: Z kWh) total if draw. Wh accumulation persisted per day (`storedWh-<day>`, `gridWh-<day>`, purged like the other keys). The stored share deducts AC charging (`EnergyMath.solarToBattery`, hub flow balance).
- **`Sources/Shared/EnergyMath.swift`**: pure logic extracted (first brick of the Monitor tests) + **9 unit tests** (solar/AC/mixed charge, bounds, ratio) — 20/20 tests green.
- "Solaire du jour" line also added to the **dashboard's** Solar production card (Vincent had not seen it: it was only in the panel). PR #15 updated (`0bbbea1`).
- **PR #15 merged into main** (`cfda895`, CI green, rendering validated by Vincent), branch deleted.

### Fixed (code review — 5 fixes validated by Vincent)
- **Polling debounce**: the host field and the interval slider relaunched the poll at every keystroke/step (partial addresses queried). `scheduleRestart()` waits for 800 ms of calm before relaunching.
- **Remembered fallback host**: once switched to the fallback (VPN), the app stays on it and only retests the main host every 2 min — before, each poll paid the 5 s timeout of the main one. Immediate return to the main one after a host modification (reset in `restart()`).
- **Data kept offline**: on a network failure > 60 s, the panel no longer falls back to "No data" — it keeps the last values grayed out (opacity 0.55) with "Hors ligne — dernières données à HH:MM:SS" (Offline — last data at HH:MM:SS) in orange in the header (`MenuView.isStale`), same pattern as the widget.
- **Local day, not UTC**: `Monitor.dayKey` used ISO8601 (UTC) — the day's counters rolled over at 1–2 a.m. Replaced by a `yyyy-MM-dd` DateFormatter in local time zone, consistent with the 5 min curve and the history.
- **Zero build warnings**: non-Sendable `self` captures fixed in `PermissionsStatus.refresh()` (guard let + strong capture) and the widget's `CFBundleVersion`/`CFBundleShortVersionString` aligned with the app in `project.yml` (7 / 1.5.0). Tests: 11/11 green.

### Changed
- Action icons of the panel header (dashboard, Sun, settings, ⋯ menu) switched from `.secondary` to `.primary` for better visibility (Vincent's request). Debug build relaunched.
- Then a distinct color per icon (Vincent's request): dashboard blue, Sun orange, settings teal, ⋯ menu stays `.primary` (`headerButton` now takes a `color` parameter).

## 2026-08-05 (release v1.5.0)

### Released
- **v1.5.0** (build 7): DMG signed Developer ID, notarized (Accepted, stapled, verified `spctl` → Notarized Developer ID), Sparkle EdDSA-signed. GitHub release `v1.5.0` with notes, `appcast.xml` updated on main (commit 87c8777). Notarized version installed in /Applications (widget re-registered). Content: hub flow diagram, Sun window, Juicy-style panel, reorganized settings, period selector, stats, optional notifications, € / CO₂ savings, permission checks, tests + CI.

## 2026-08-05

### Docs
- Screenshots regenerated via ImageRenderer harness with realistic data: `docs/panel-light.png`, `panel-dark.png` (new Juicy-style panel — static replica `ShotMenuView` because ImageRenderer renders AppKit controls as 🚫), `dashboard.png` (hub diagram), **new `docs/sun.png`** (Sun window). README: "New in 1.5" paragraph, Sun window section, Sources/Tests layout up to date, roadmap v1.5 [x] + v1.6/v2.0. Landing page: feature cards (period/stats, hub dashboard, Sun window, notifications), new dashboard + Sun section with screenshots.
- `SunView` refactored into `SunView` + `SunContent` (separate ScrollView — required by ImageRenderer, same pattern as DashboardContent).

### Changed (ergonomics — Vincent's request)
- **Juicy-style panel**: header with icon + "Zendure Monitor" + update time, and the actions as icon buttons at the top right (dashboard, Sun, settings, ⋯ menu for updates/quit). The row of text buttons at the bottom and the big "Ouvrir le tableau de bord" (Open the dashboard) button disappear; the bottom of the panel now only serves warnings (fallback host, errors, TCC, notifications).
- **Settings reorganized**: new **Soleil** tab (Position + Panels/peak power), Refresh moved into **Appareil**, **Général** slimmed down (login + Savings + Permissions, moved last), width 500 pt — each tab keeps a height fitted to its content (vertical `fixedSize`).

### Added (backlog TODOS wave 1)
- **Dedicated "Soleil" window** (the dashboard stays a dashboard — Vincent's request): Window "sun" scene, "Soleil" button in the panel footer, SunCard removed from the dashboard. Dock policy shared between windows via a `WindowPolicy` counter. **Sun module v2**: "Course du soleil et production" (Sun course and production) card (arc + yellow area of the day's curve on the same sunrise→sunset time axis, sun positioned in real time) and "Productible théorique" (Theoretical yield) card (configurable peak power × sin(elevation) × 0.9, measured production, estimated efficiency).
- **Period selector** on the panel's main chart: 15 min / Day / 14 d. Day curve = max per 5 min slice, persisted per day (`solarCurve-<day>`, purge > 15 d).
- **Statistics**: day's power peak (persisted `peakW-<day>`) and comparison with yesterday (%), displayed under the panel's and dashboard's histogram.
- **Optional notifications** (opt-in, Settings → Notifications): battery full (at the socSet ceiling), grid draw > 50 W while solar produces > 100 W (max 1/h), production record broken (1/day).
- **Savings**: configurable kWh price and CO₂ factor (Settings → General); "Économie du jour" (Savings of the day) in the Production card and "≈ X € · Y kg CO₂ évités" total in the dashboard history.
- **Tests + CI**: `ZendureMonitorTests` target without host app (9 tests: parser nested/flat/string/sentinel/discharge, SunCalc Ajaccio solstice/polar night/night, Format) — `Format` moved to `Sources/Shared/`. GitHub Actions workflow `.github/workflows/ci.yml` (xcodegen + build + test on every PR and main push). All green locally.

### Fixed
- "Utiliser la position de ce Mac" (Use this Mac's position) button spinning forever: cause = no timeout and no pre-check — if macOS Location Services is globally off, `requestWhenInUseAuthorization()` produces no callback. `LocationFetcher` v2: `locationServicesEnabled()` pre-check (off the main thread), 25 s timeout, distinct messages (service off / denied / no fix / locationd silence) — never an infinite wait again.

### Added
- Upstream permission check (Vincent's request): "Autorisations" (Permissions) section in Settings → General (Local network — state inferred from polls, macOS has no API —, Location, Notifications, with buttons to the right panes) + startup warning in the panel if the battery alert is enabled but notifications are denied (`Monitor.notificationsDenied`).
- Double-click on any panel chart (solar/battery/home sparklines, histogram) → opens the dashboard (modifier `openDashboardOnDoubleClick`, help tooltip).
- "Utiliser la position de ce Mac" button (Sun module): one-shot CoreLocation `LocationFetcher` (km accuracy, authorization requested on click only), available in Settings → General and in the Sun card as long as the position is not set. `NSLocation*UsageDescription` keys added in `project.yml` (⚠️ Info.plist is generated by xcodegen — any key must go through `project.yml`, a direct edit is overwritten by `xcodegen generate`).
- Flow diagram v3 (Vincent's request): the **SolarFlow becomes the central hub again** (teal circle with temperature) and the **batteries become a satellite** (compact SOC ring, link that changes direction according to charge/discharge), alongside 4 other peripherals: Panels, Home, Public grid and **Off-grid socket** (new parsed field `gridOffPower` → `DeviceState.offGridPower`, spotted in the device's real report). Radial links animated only when the flow exists, watts in a pad.
- **Sun module**: `SunCalc` (100% local NOAA algorithm, ~1 min accuracy — sunrise/sunset at -0.833°, solar noon, day length, elevation/azimuth, max elevation) + `SunCard` card in the dashboard (sun course arc with current position, recomputed every minute) + latitude/longitude setting in Settings → General (`sunLatitude`/`sunLongitude`, never transmitted). Card hidden behind a help message as long as the position is not filled in. Verified by harness: consistent ephemeris for the [région] in early August.
- Detection of the "local network" TCC block (Vincent's request after replacing the app in /Applications broke the grant): `Monitor.looksLikeLocalNetworkDenial` inspects the error chain (POSIX 50 ENETDOWN — the TN3179 signature of the denial —, POSIX 65, -1009/-1004/-1003) and publishes `localNetworkDenied`. New `LocalNetworkHint` component (orange banner, worded in the conditional) displayed in the panel and the dashboard: "Ouvrir les réglages…" (Open settings…) button (deep link `x-apple.systempreferences…Privacy_LocalNetwork`) + "Réessayer" (Retry). FR/EN i18n.

### Changed
- Energy flow diagram redesigned (Vincent's feedback: "it feels like the batteries are supplying energy all the time"): flows are decomposed from the power balance (solar → battery, solar → home via the top arc without transiting through the battery, battery → home, grid → battery, grid → home via the bottom arc). Each link only animates if its real flow is > 1 W and displays its power in a pad; the central node is now labeled "Batterie" (Battery). Verified by ImageRenderer harness (3 scenarios: solar+charge, night discharge, AC charge).
- More visible dashboard launch: full-width `.borderedProminent` button "Ouvrir le tableau de bord" in the panel (replaces the small text button in the footer).
- The app appears in the Dock and Cmd-Tab (with its icon) as long as the Dashboard window is open: `NSApp.setActivationPolicy(.regular)` toggle on opening, back to `.accessory` on closing (the app is LSUIElement).

## 2026-08-04 (v1.4.0: dashboard + collector)

### Added
- "Tableau de bord" (Dashboard) window (Window scene, button in the panel): `EnergyFlowView` (animated flow diagram — scrolling dotted lines whose speed follows the power, central SolarFlow node with SOC ring), enriched Production/Battery/Device/History cards. New parsed fields: hyperTmp (°C), remainOutTime (min, 59940 = unavailable), rssi, BatVolt, socSet/minSoc (0.1%).
- 24/7 collector (`Scripts/collector/`): python stdlib (30 s poll → SQLite → JSON API /daily /today /recent /health, port 8899), LaunchAgent deployed on [Mac-collecteur]. App: "Serveur d'historique" (History server) setting, server/local merge (max per day), "collecteur 24/7" badge.
- v1.4 fixes: 0 baseline on the battery sparkline, debounce + 0 W confirmation in Control, "no device found" message, widget grayed out if data > 15 min old.

### Blocked
- ⚠️ The collector on [Mac-collecteur] is blocked by TCC "local network" (`No route to host` errno 65 from the python LaunchAgent, whereas curl passes over SSH — SSH sessions are exempt). Waiting: Vincent must authorize python3/the local network prompt on [Mac-collecteur] (screen sharing). Plan B if no prompt: root LaunchDaemon.

### Learned
- ImageRenderer does not render the inside of a ScrollView → separate the content (DashboardContent) from its ScrollView.

## 2026-08-04 (Tailscale remote access operational)

### Added
- Standalone Tailscale (1.102.1) installed on [Mac-collecteur] (always-on Mac mini, 192.168.x.39) and on the MacBook. [Mac-collecteur] = subnet router: `--advertise-routes=192.168.x.0/24` (set over SSH via the app's CLI), route approved in the admin console. Fallback host `[IP-SolarFlow-1]` configured in the app.
- MacBook SSH key authorized on [Mac-collecteur] (installed via screen sharing — password SSH was refusing).

### Learned
- The GUI app's Tailscale CLI fails over SSH ("CLIError error 1") as long as the user is not authenticated in the graphical session; it then works, including `set --advertise-routes`.
- To verify a route approval on the server side: `tailscale status --json` → `Self.AllowedIPs` must contain the subnet (the local `AdvertiseRoutes` announcement is not enough).

## 2026-08-04 (v1.3.1 release, PR #11)

### Released
- v1.3.1 (build 5): app icon. 2.2 MB DMG notarized + stapled, GitHub release, appcast up to date. Installed in /Applications, verified (Gatekeeper accepted, version 1.3.1, ~1 kW live).

### Learned
- After replacing the app in /Applications, PluginKit may lose the widget registration: `pluginkit -a <appex>` re-registers it immediately.

## 2026-08-04 (icon, PR #10)

### Added
- App icon: sun + battery gauge on a midnight blue gradient, standard macOS margins. Generated by code (`Scripts/generate-icon.swift`, SwiftUI ImageRenderer) → all sizes in `Assets.xcassets/AppIcon.appiconset`; `ASSETCATALOG_COMPILER_APPICON_NAME` in project.yml.

### Learned
- Xcode 26+ **Debug** builds embed `ZendureMonitor.debug.dylib`: re-sign it too, otherwise dyld refuses (Team ID mismatch). To install a Dev ID-signed local build, prefer a **Release** build staged via ditto then signed appex → Sparkle → app (never `--deep`, which overwrites the appex's entitlements).

### Installed
- Developer ID-signed Release build installed in /Applications (icon visible). Not released — propose v1.3.1/v1.4.0.

## 2026-08-04 (v1.3.0 release, PR #9)

### Added
- macOS widget (WidgetKit, small/medium): production, battery, home, day's energy, mini-curve. Sandboxed extension `fr.lauriat.ZendureMonitor.widget`, App Group `KFLACS69T9.fr.lauriat.ZendureMonitor`, atomic JSON snapshot (MacInside pattern). The app publishes at every poll + WidgetKit reload every 2 min.
- Control tab: acMode (AC charge / feed-in), outputLimit, inputLimit via `POST /properties/write` (values pre-filled from the device, explicit warning). POST format validated against the mock — never tested in writing on the real battery.
- CSV export (≤ 90 days) from the History card (NSSavePanel).
- release.sh: signing of `.appex` before the app, each with its entitlements; app signed with its own (App Group).

### Learned
- macOS (Tahoe) protects Group Containers via TCC: a non-entitled process sees an empty folder and `touch` fails with "Operation not permitted". Reliable check = Developer ID-signed CLI reader with the group's entitlement.

### Verified
- Notarization accepted (appex included), Gatekeeper OK, widget registered (`pluginkit -m` → fr.lauriat.ZendureMonitor.widget), snapshot read with fresh data (1,030 W, 21%). v1.3.0 installed in /Applications.

## 2026-08-04 (v1.2.0 release, PR #7 + #8)

### Added
- "Historique" (History) card: kWh/day histogram (14 days displayed, 90 kept then purged, UserDefaults keys `energyWh-<yyyy-MM-dd>`), period total, highlighted day bar. `DailyBarChart` component (Charts, MacInside style).
- v1.2.0 published: notarized DMG (1.1 MB), GitHub release, appcast `sparkle:version=3` — update served to 1.0.0/1.1.0 installs.
- README: light/dark screenshots regenerated with the History card; roadmap checked.

### Verified
- PR #7 merged, appcast online (1.2.0), stapler OK, Gatekeeper "Notarized Developer ID", official 1.2.0 installed in /Applications (≈1 kW live).

## 2026-08-04 (settings tabs / i18n / theme, PR #6)

### Added
- Settings split into 5 tabs: Device, Display, General, Notifications, Remote (much more compact window, 440 pt).
- FR/EN localization via String Catalog (`Sources/Localizable.xcstrings`, source fr, dev region fr — English is chosen automatically on an EN system).
- Auto/Dark/Light theme (Display tab, `NSApp.appearance`).
- Light/dark screenshots in `docs/` (headless ImageRenderer rendering, footer buttons cropped — off-window artifact), integrated into the README.

### Learned
- `NSApp` is nil in the CLI harness → `_ = NSApplication.shared` before creating Monitor.
- Assignments in `init` do not trigger the `didSet`s of @Published — settings are not rewritten at launch.

## 2026-08-04 (options/alerts/remote, PR #5)

### Added
- Menu bar display options: production W / battery % / home W (or icon only).
- Launch at login (SMAppService) in Settings → General.
- Low battery alert (UserNotifications, threshold 5–50%, default 15%).
- Day's solar energy counter (poll integration, persisted per day in UserDefaults), displayed in the Production card.
- Per-pack detail in the Battery card: SOC, temperature (maxTemp 0.1 K → °C), power — inspired by the HA integration.
- Optional fallback host (remote access via VPN): tried when the main address does not respond; "via the fallback host" indicator in the panel; README section "Remote access" (⚠️ never port-forward port 80, API has no auth).

### Installed
- Dev ID build installed in /Applications, verified live (1.0 kW, battery 23%). Release v1.2.0 not published (awaiting the go).

## 2026-08-04 (v1.1.0 release, PR #4)

### Added
- v1.1.0 published: version bump (marketing 1.1.0, build 2), notarized DMG (1.0 MB), GitHub release, appcast updated — first update actually served to 1.0.0 installs via Sparkle.
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
- Sparkle 2.9.1 auto-update: SPM dependency, `Updater.swift` (SPUStandardUpdaterController), "Mises à jour…" (Updates…) button in the panel, `SUFeedURL` → appcast.xml on main, `SUPublicEDKey` (new EdDSA key, keychain account "ZendureMonitor", backup in ~/.sparkle-keys/).
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
