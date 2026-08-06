# ZendureMonitor 1.7.0

## New

- **Large widget (systemLarge)**: the 14-day production histogram now lives on your desktop — daily energy bars with today highlighted, alongside the live solar/battery/home metrics.
- **Local weather in the Sun window**: cloud cover and sunshine forecast from Open-Meteo (no account, no API key), with a cloud-adjusted production estimate for the day.
- **Sun window redesigned**: hero chart (sun elevation × solar production × theoretical potential) plus three compact columns — ephemeris, weather, and yield — everything visible without scrolling (820×540).

## Fixed

- Cloud-factor model now uses the correct Kasten–Czeplak exponent (3.4), with unit tests locking it in.

## Under the hood

- `DailyAccumulator` extracted as a pure, fully-tested component (bounded dt, day rollover, buckets, peak, collector merge) — 8 new tests, 32 total, all green in CI.

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
