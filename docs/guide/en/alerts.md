---
title: Alerts and savings
---

[🇫🇷 Version française](../fr/alertes.md)

# Alerts and savings

## Low battery alert

In **Settings → Notifications**, the **low battery alert** (on by default) sends a macOS notification when the state of charge drops below a threshold adjustable from **5 to 50%** in steps of 5 (default 15%). The alert does not repeat in a loop: it re-arms once the battery climbs at least 5 points above the threshold.

![Notification settings tab](../images/settings-notifications.png)

*The Notifications tab: low battery alert and optional notifications.*

## Optional notifications

Three extra notifications, off by default (opt-in):

- **Battery full** — when the level reaches the charge ceiling configured on the device (the upper bound of the SOC range);
- **Grid draw while solar is producing** — when the SolarFlow draws more than 50 W from the grid while solar produces more than 100 W, a sign of an unexpected setting; at most one notification per hour;
- **Production record beaten** — as soon as today's production exceeds the best known day in the history (a few days of history are needed for the comparison to make sense).

The first time you enable an alert, macOS asks for permission to send notifications. If they are denied, the panel says so with a banner and an **Allow…** button that opens System Settings.

## Savings: € and CO₂

In **Settings → General**, **Savings** section:

- **kWh price (€)** — default 0.20 €;
- **CO₂ factor (g/kWh)** — default 55 g (roughly the French electricity mix; adjust it to your country).

These two parameters feed **Today's savings** (Production card of the dashboard) and the 14-day cumulated estimate "**≈ X € · Y kg CO₂ avoided**" (History card of the dashboard).

---

[← Battery control](control.md) | [Index](../README.md) | [Remote access →](remote-access.md)
