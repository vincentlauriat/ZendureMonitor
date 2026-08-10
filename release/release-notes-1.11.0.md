# ZendureMonitor 1.11.0

## Added — automatic local ⇄ cloud switching

- **New "Basculer automatiquement" option** (Settings → Data source): in local mode, after 2 consecutive failed polls (fallback host included) with a Cloud Key saved, the app switches itself to Cloud mode — typically when your Mac leaves the home network. In Cloud mode it probes the local host every 60 s and switches back to local as soon as the SolarFlow answers again.
- The connection footer shows **"Cloud Zendure — bascule auto"** when the current cloud mode was chosen automatically, so you always know why you're on the cloud path.

## Added — collapsible and configurable panel cards

- **Every card in the menu bar panel can now be collapsed** with a click on its header (animated chevron, state remembered per card). Collapsed, a card shrinks to one line showing its key value: solar W, battery %, home W, total consumption W, 14-day total kWh.
- **New Settings → Display → "Cartes du panneau" section**: a toggle per card to show or hide it entirely.

## Under the hood

- `MetricCard` gains optional `collapseKey`/`collapsedSummary` parameters — dashboard and Sun window cards are untouched.
- New `Monitor.autoSwitchMode` (persisted), failure-streak switching logic and a 60 s local probe (`autoSwitchBackIfLocalReachable`).
- All tests green.

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
