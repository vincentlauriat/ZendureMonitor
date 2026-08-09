# ZendureMonitor 1.9.0

## New — the Sun window, rebuilt around your panel arrays

The Sun window used to know one thing about your installation: its total peak power. It now knows **where your panels point**, and everything follows from that.

- **One array per orientation** — give each one a name, its peak power in Wp, its azimuth and its tilt (Settings → Sun, or straight from the window). If you had only entered a peak power before, it carries over as a single due-south array at 30° — nothing to retype.
- **Animated sky dome** — the sun's real path over the day hour by hour (the part already travelled bright, the rest dimmed), both **solstice arcs** as the bounds the sun never crosses at your location, today's measured production placed where the sun actually stood, and a **marker per array** showing its live incidence gap that lights up when the sun reaches it. The sky itself shifts from starry night through twilight and golden hour to broad daylight.
- **Solar compass** — the same sky seen from above, with the true **25° and 50° iso-incidence loops** around each array's aiming direction: the patch of sky in which that array produces near its optimum.
- **Adjust orientation live** — two sliders per array, azimuth and tilt, right in the window. The dome, the compass, the incidence and the output all follow the gesture. It is the fastest way to find the orientation that really matches your roof.
- **Per-array breakdown** — clear-sky output right now, incidence in degrees, the share of peak irradiance actually captured, the array's best hour of the day and its potential in kWh.
- **Richer ephemerides** — civil, nautical and astronomical twilights, both golden hours, the change in day length since yesterday down to the second, and the next solstice or equinox with its countdown.
- **Everything on one screen** — three bands, no scrolling.

## Fixed

- **The clear-sky model ignored the atmosphere.** A due-west array announced its full power at sunset — 323 W at 1.6° of elevation. The path light travels through the atmosphere is now part of the model (Meinel's law), and that same array reports 30 W.
- **Deleting every panel array wiped your peak power.** The stored value was overwritten with 0, losing what you had entered under 1.8 with no way back. It is now only written when the total is non-zero.
- The sun was placed on a decorative half-circle by linear time progression; it is placed by its real elevation and azimuth.

## Under the hood

- New `SolarGeometry` (pure Foundation, fully tested): panel arrays and their persistence, incidence cosine, plane-of-array factor, per-array clear-sky output and daily energy, best hour, 3D iso-incidence locus, air mass, shadow length.
- `SunCalc` extended with the day's track, twilight crossings, declination and solstice/equinox bisection — existing signatures untouched, so the 1.8 outage alerts keep working.
- **60 tests, all green in CI**, including a sweep proving every slider step survives storage round-tripping exactly.
- Full French and English localization, plus 18 English strings that had been missing from this surface since the beginning.

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
