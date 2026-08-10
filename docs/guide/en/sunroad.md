# The SunRoad window (3D)

*New in 2.0.*

SunRoad puts **your house, your neighborhood and the sun in a real 3D scene** — inspired by the [Helios](https://github.com/ReikanYsora/helios) Home Assistant card, but in native 3D: the sun is an actual light source, and the cast shadows are real.

Open it with the **indigo cube** in the panel header. The window reuses the location and panel arrays configured in the [Sun window](sun.md).

## The scene

- **The neighborhood**: building footprints (120 m radius) and roads (170 m) come from OpenStreetMap — real heights when the map knows them, road widths from their class (residential street, primary road, footpath…). **Your house is detected automatically** (the footprint closest to the configured position) and highlighted in amber. Everything is cached: one download, ↻ button to refresh.
- **The sun, for real**: the day's arc (NOAA ephemerides computed locally) with a marker at every full hour, and the sun as a **directional light** — the neighbors' shadows sweep across the scene through the day, and you can see whether they reach your panels.
- **Your panel arrays**: placed with their real azimuth and tilt, sized from their peak power.
- **A living sky**: night, dawn, daylight, dusk — plus the **real weather** (Open-Meteo): cloud cover veils the light and grays the sky.

## Live energy

**Animated beads** show the flows at the pace of the measured watts: panels → house (yellow), grid pylon → house (orange), house ↔ battery (green charging, orange discharging). Along the arc, a **production ribbon** draws your solar day: one bar per quarter hour, exactly where the sun stood.

## ±48 h timeline

The slider at the bottom moves time up to two days backward or forward: sun, shadows, sky and arc follow. The **Now** button returns to real time (the scene then follows the clock, minute by minute).

## Layers and wall mode

Every layer toggles on demand (checkboxes): buildings, roads, sun arc, panels, compass, energy. The **crossed-eye** button hides the whole interface — great on a spare display — and a discreet eye brings it back.

## Good to know

- Neighborhood fidelity depends on OpenStreetMap: without a height tag, a building defaults to 6 m.
- Without network (or if Overpass is busy), the scene stays usable with a stylized house; the neighborhood comes back on the next load.
- Drag to orbit, scroll to zoom.

---

[← The History window](history.md) | [Index](../README.md) | [Widgets →](widgets.md)
