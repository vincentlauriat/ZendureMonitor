---
title: Battery control
---

[🇫🇷 Version française](../fr/controle.md)

# Battery control

The **Settings → Control** tab lets you drive a few SolarFlow settings straight from the Mac.

> ⚠️ **These commands really act on the battery.** They are sent to the device through its local API (`POST /properties/write`), exactly like the Zendure app would. Change these settings knowingly.

![Control settings tab](../images/settings-control.png)

*The Control tab: AC mode and charge/output limits.*

## AC mode

Two modes, confirmed with **Apply mode**:

- **Charge (from the mains)** — the battery charges from the grid (useful during off-peak hours);
- **Discharge (to the home)** — the battery powers the home (the usual solar operation).

## Power limits

- **Output limit** — cap on the power the battery delivers, adjustable from 0 to 2400 W in 50 W steps;
- **Charge limit** — cap on the charging power, adjustable from 0 to 2400 W in 100 W steps.

Each slider has its own **Apply** button. The sliders are pre-filled with the device's current values when the tab opens.

## Safeguards

- Applying a **0 W limit completely cuts that flow** (no more output, or no more charging): the app asks for an explicit confirmation before sending the command.
- After each send, the buttons stay disabled for 2 seconds to prevent double sends.
- The commands are disabled while the app has no connection to the battery. They go to the currently active host (the local one, or the fallback host when you are away).

Outside this tab, the app is strictly **read-only**: monitoring never writes anything to the battery.

---

[← Widgets](widgets.md) | [Index](../README.md) | [Alerts and savings →](alerts.md)
