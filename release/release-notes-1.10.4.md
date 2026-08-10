# ZendureMonitor 1.10.4

## Changed — honest home consumption when the Smart CT is out of reach

- **The UI now distinguishes an unreachable Smart CT from no Smart CT at all.** The meter is only readable on the local network — the cloud never relays it — so away from home (typically in Cloud mode) its measurement drops out. The home consumption card previously fell back to the same message as if no meter were configured; it now shows "via SolarFlow only" with a clear notice that the home's grid draw is not counted and the value is partial.
- **The dashboard's flow-diagram caption makes the same distinction** — measured / configured but unreachable / not configured.

## Under the hood

- New `Monitor.ctConfigured` helper (CT host set in Settings → Network), shared by the panel card and the dashboard caption.

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
