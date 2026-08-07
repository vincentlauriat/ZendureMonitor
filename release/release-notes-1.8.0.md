# ZendureMonitor 1.8.0

## New — outage alerts

Born from a real incident: a SolarFlow went into fault (full battery, no injection to the home) and then dropped off the network entirely — and the app stayed politely silent. Not anymore:

- **"SolarFlow unreachable" notification** — fires after N minutes without a response from the device (adjustable 5–60 min, default 10). One notification per outage episode, re-armed when the device comes back. **Enabled by default.**
- **"Abnormal solar production" notification** — the device responds but produces and injects nothing for 30 minutes while the sun is above 20° elevation (computed locally; requires the position configured in the Sun tab). Catches a faulted unit that is still on the network. **Enabled by default.**
- **Menu bar warning** — while the device is unreachable past the threshold, the menu bar switches to a clear ⚠️ "offline" state instead of just dimming the panel values.

Both alerts can be tuned or turned off in Settings → Notifications → "Alertes de panne".

## Under the hood

- Detection logic extracted as a pure, fully-tested `OutageWatchdog` (8 new tests — 40 total, all green in CI).
- French and English localization for all new strings.

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
