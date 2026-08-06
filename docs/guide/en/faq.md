---
title: FAQ and troubleshooting
---

[🇫🇷 Version française](../fr/faq.md)

# FAQ and troubleshooting

## The "local network" permission disappeared after an update

Symptom: after updating (or reinstalling) the app, the battery is no longer reachable over local Wi-Fi, although nothing changed on the network. Cause: replacing the app in /Applications can leave a stale LaunchServices registration, and the "Local Network" TCC permission no longer applies to the new bundle.

In order:

1. **System Settings → Privacy & Security → Local Network**: toggle Zendure Monitor's switch off and on, then click **Retry** in the panel's banner.
2. If that is not enough, re-register the app with LaunchServices and relaunch it:

   ```bash
   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/ZendureMonitor.app
   killall Finder Dock
   ```

3. As a last resort, restart the Mac.

> Diagnostic trap: this permission does not apply to VPN interfaces. If the battery answers over Tailscale but not over local Wi-Fi, it really is a "Local Network" block — always test from the LAN.

## The panel shows "Offline" or "No data"

- **Offline** (dimmed values): the app has data but the battery has not answered for more than 60 seconds. Check that the SolarFlow is powered and on Wi-Fi, and that the Mac is on the same network.
- **No data**: no connection has succeeded yet. Check the address in **Settings → Device** (the **Test connection** button) and the local network permission (above).
- Bonjour discovery finds nothing? The local API may be disabled: in the Zendure mobile app, add a **HEMS** integration and then quit it — this is the documented way to persistently enable it.

## The widget does not update

- The widget is fed by the app: **the app must be running** for the data to be fresh. Past 15 minutes without data, the widget deliberately dims and shows the reading's age.
- "Open Zendure Monitor": launch the app once to publish the first reading.
- After an app update, if the widget vanished from the list or stays frozen, re-register the extension:

  ```bash
  pluginkit -a /Applications/ZendureMonitor.app/Contents/PlugIns/ZendureWidget.appex
  ```

## The app icon is white/generic in the Finder

Another possible aftermath of replacing the app: the LaunchServices registration is stale. Run the `lsregister -f` command above, and if the icon stays white in the Finder (but correct in the Dock):

```bash
touch /Applications/ZendureMonitor.app
killall iconservicesagent Finder
```

## Today's data is incomplete

The app integrates energy **while it is running**: if the Mac is off or asleep part of the day, those hours are missing from the counter (the displayed production is then a lower bound). Two options:

- keep the Mac on with the app running (enable **Launch at login** in Settings → General);
- install the [24/7 collector](remote-access.md#the-optional-247-collector) on an always-on machine: the history becomes complete, regardless of your Mac's uptime.

## Exporting the history as CSV

In the panel, **History** card, click the share button (arrow pointing up): the app saves a CSV file with one line per stored day (up to 90 days), columns `date,wh`.

## How long is the history kept?

Daily totals are kept for **90 days** on the Mac; the panel and the dashboard display the last 14. With the 24/7 collector, the complete history lives in the collector's SQLite database.

## Is the app safe for the battery?

Monitoring is strictly **read-only** (it only reads `GET /properties/report`). Only the [Control](control.md) tab sends commands, always at your initiative, with a confirmation for risky values.

---

[← Remote access](remote-access.md) | [Index](../README.md)
