# ZendureMonitor 1.10.3

## Added — total home consumption in the menu bar panel

- **New "Home consumption" card** in the menu bar panel, between Flows and History. With a Smart CT configured, it shows the house's total consumption — grid draw (excluding the SolarFlow's AC charging, which the meter also sees) plus the SolarFlow's output to the home — with a per-source breakdown: "From the SolarFlow" and "From the grid".
- **Without a Smart CT**, the card honestly shows only what is measurable (the SolarFlow output) and points to Settings → Network to add the meter.

## Under the hood

- Home-consumption math is now centralized in `EnergyMath` (`gridToHome`, `homeTotal`); the dashboard's flow diagram uses the same shared helpers — one source of truth for both views.
- All tests green; build verified.

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
