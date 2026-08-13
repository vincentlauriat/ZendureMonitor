---
title: The dashboard
---

[🇫🇷 Version française](../fr/tableau-de-bord.md)

# The Dashboard window

Open it from the **blue gauge** icon in the panel header, or by double-clicking any chart in the panel. While it is open, the app also appears in the Dock and in Cmd-Tab.

![Dashboard](../images/dashboard-light.png)

*The dashboard: animated flow diagram on top, indicator cards below.*

## The energy flow: two readings

A picker at the top of the card switches between **Schematic** and **Sankey**. Both show the **same flows and the same values** — only the reading changes, and your choice is remembered.

### Schematic

The **SolarFlow sits at the center** of the diagram; around it, five satellites:

- **Solar panels** — the photovoltaic input;
- **Batteries** — with a state-of-charge ring and a bidirectional link (charging or discharging);
- **Public grid** — electricity drawn from the mains;
- **Home** — the AC output to your installation;
- **Off-grid outlet** — the SolarFlow's backup outlet, when the device reports it.

Each link **animates only when energy actually flows**, in the real direction, with the live wattage shown in a badge on the link. The schematic shows the **topology** of your installation: what is wired to what.

### Sankey

Here the **ribbon width is the wattage**: the split reads at a glance (how much of the solar goes to the house, how much goes into the battery). Sources are on the left (Grid, Panels, Batteries discharging), the SolarFlow in the middle, uses on the right (Home, Batteries charging, off-grid outlet).

Two things worth knowing when reading it:

- **The hub never balances exactly** (conversion losses, measurement noise). A Sankey visually asserts that everything in comes back out, so the residual is drawn explicitly in grey as **"Pertes & conversion"** (more goes in than comes out) or **"Écart de mesure"** (the other way round) — never silently absorbed.
- **Without a Smart CT**, the home's direct grid draw exists but is not measured. It keeps a **fixed-width hatched band**, off scale, marked "non mesuré", and caps the Home node's bar the same way: giving it a width would invent a number, dropping it would claim it is zero.

## Solar production card

The instantaneous power in very large type, today's energy, a sparkline, then the details: each **PV input** (MPPT), **To the home**, **From the grid**, and **Today's savings** in euros (computed with the configured kWh price, see [Alerts and savings](alerts.md)). At the bottom, **today's solar split** ("X% direct · Y% stored") and the cumulated grid draw.

## Battery card

- The circular SOC gauge;
- **Charge** / **Discharge** in watts;
- The battery **voltage** (V);
- The **estimated runtime** (remaining time reported by the device);
- A sparkline of the battery flow;
- Per-**pack** details (SOC, temperature, power);
- The **configured SOC range** (charge minimum – maximum set on the device).

## Device card

- Device **temperature** (red above 45 °C);
- **WiFi signal** in dBm (green from −60 dBm, orange down to −75 dBm, red below);
- **AC mode** — Charge (from the mains) or Discharge (to the home);
- Current **charge limit** and **output limit** (W);
- **Serial number**;
- **Connection** — local network or fallback host;
- The time of the last data **update**.

## History card

The 14-day histogram with the period **total**, the period **record**, today's **peak** and the **vs yesterday** comparison. The bottom line estimates the cumulated savings: **≈ X € · Y kg CO₂ avoided** (parameters in Settings → General). When the history comes from the [24/7 collector](remote-access.md#the-optional-247-collector), a green "24/7 collector" badge says so.

---

[← The panel](panel.md) | [Index](../README.md) | [The History window →](history.md)
