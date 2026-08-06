---
title: Widgets
---

[🇫🇷 Version française](../fr/widgets.md)

# Widgets

Zendure Monitor ships a "Solar production" widget in **three sizes**, for the desktop or Notification Center.

## Adding a widget

1. Right-click the desktop and choose **Edit Widgets…** (or open Notification Center and click **Edit Widgets** at the bottom).
2. Find **Zendure Monitor** in the list, pick a size, and drag the widget wherever you want.

If the widget says "Open Zendure Monitor", launch the app once: the app is what feeds the widget with data.

## The three sizes

![Small widget](../images/widget-small.png)

*Small: instantaneous production, battery, home and today's energy.*

![Medium widget](../images/widget-medium.png)

*Medium: the same information, plus a mini-curve of the recent production.*

![Large widget](../images/widget-large.png)

*Large: additionally, the last-14-days histogram — today's bar at full opacity, previous days dimmed — with the period total.*

Content common to all three sizes: the instantaneous **solar production** (W), the **battery level** (%, red at 15% or below), the power **sent to the home** (W), **today's energy** and the reading's time.

## Data freshness

The widget is fed by the app (it does not contact the battery itself):

- while the app is running, macOS refreshes the widget regularly;
- if the data is **older than 15 minutes** (app closed, Mac back from sleep…), the widget **dims** and shows the reading's age with an orange clock, rather than pretending to be real-time.

If the widget seems stuck, see the [FAQ](faq.md#the-widget-does-not-update).

---

[← The Sun window](sun.md) | [Index](../README.md) | [Battery control →](control.md)
