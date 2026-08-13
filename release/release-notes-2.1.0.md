## SunRoad reads your energy day at a glance

**Consumption curve, Helios-style.** Home consumption is now a continuous blue curve running the full 24-hour circle of the scene — position on the circle is the hour (night passes on the north side), height is the watts, with translucent pins marking the quarter hours. A live **“⌂ n W” badge** floats above the house (Smart CT whole-home total when available, SolarFlow feed-in otherwise).

**Expected vs. actual production.** A translucent yellow curve draws the clear-sky production expected from your configured panel arrays, on the ground under the sun's course — on the same circle, baseline and scale as the teal bars of actual production. Each bar should reach the curve when the day keeps its promise; the gap reads instantly. The forecast follows the ±48 h timeline (scrub to tomorrow to preview the solar day) and reacts live to the orientation sliders.

## Fixes

- **History window: the Smart Meter 3CT no longer shows an empty card.** The Zendure cloud answers its history queries with a complete solarFlow structure filled with zeros; the app now treats all-zero payloads as “no history” — the meter is hidden with a discreet note, and its cached zero-days are purged.
- **Local polling can no longer mistake a Smart CT for a SolarFlow.** Both devices expose the same local API; if the configured device address answers like a CT meter (which can happen after a DHCP change), the poll now fails with an explicit message instead of silently displaying zeros — and the auto local/cloud switch no longer bounces on bad data.
