## Zendure Monitor 1.1.0

### New: trend graphs 📈

The panel is redesigned as metric cards (shared design language with MacInside):

- **Solar production** — large live value, trend sparkline, and per-MPPT input legend
- **Battery** — state-of-charge ring gauge (color-coded), charge/discharge power, battery flow sparkline
- **Flows** — output to home and grid input, with a home consumption sparkline

Sparklines keep a rolling ~15 min history (180 samples at the default 5 s poll).

### Notes
- Auto-update from 1.0.0 is delivered via Sparkle — this is the first update served through the appcast.
- macOS 14+, signed and notarized.
