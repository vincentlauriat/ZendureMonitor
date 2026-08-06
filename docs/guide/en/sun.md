---
title: The Sun window
---

[🇫🇷 Version française](../fr/soleil.md)

# The Sun window

Open it from the **orange sun** icon in the panel header. It gathers, without scrolling, the sun's path, today's production, the ephemerides, the theoretical output and the local weather.

![Sun window](../images/sun-light.png)

*The Sun window: the hero chart on top, then three columns — ephemerides, yield, weather.*

## Setting your position

The window needs your latitude and longitude: **Settings → Sun**, **Position** section. Two ways to fill them in:

- type the values manually;
- click the button that uses the **Mac's location** (a one-shot CoreLocation fix, with macOS's consent).

![Sun settings tab](../images/settings-sun.png)

*The Sun tab: position and panels' peak power.*

The ephemerides are computed **locally on the Mac** (NOAA algorithm): your position never leaves the machine for that calculation. One exception: when the weather card is in use, the coordinates (rounded to 4 decimal places) are sent to the Open-Meteo service to fetch the forecast.

## The hero chart: sun path × production

- The **dashed arc** is the sun's trajectory between sunrise and sunset, with the ☀️ icon at its current position.
- The **yellow area** is today's measured production (the maximum of each 5-minute slice), on the same time axis.

At a glance you can see whether production follows the sun's path or whether clouds (or shading) carve into it.

## Ephemerides column

Sunrise, sunset, **solar noon**, day length, the sun's current **elevation** (and today's maximum) and **azimuth**.

## Theoretical output column

Enter your panels' **peak power** (Wp) in **Settings → Sun**, Panels section. The card then shows:

- **Clear-sky theoretical** — peak power × sin(elevation) × 0.9, a simple model without weather or panel orientation;
- **Measured production** — the actual current power;
- **Estimated yield** — the ratio of the two, in percent.

## Local weather column

The weather comes from **Open-Meteo** (a free service, no account, no API key), refreshed at most every 30 minutes:

- current conditions (clear sky, cloudy, rain…) and temperature;
- **cloud cover** in percent;
- today's forecast **sunshine duration**;
- **cloud-adjusted output** — the clear-sky theoretical attenuated by cloud cover (Kasten–Czeplak formula: factor 1 − 0.75 × C^3.4, i.e. at least 25% of the theoretical under a fully overcast sky).

---

[← The dashboard](dashboard.md) | [Index](../README.md) | [Widgets →](widgets.md)
