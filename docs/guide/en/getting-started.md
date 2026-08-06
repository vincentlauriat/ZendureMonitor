---
title: Getting started
---

[🇫🇷 Version française](../fr/demarrage.md)

# Getting started

On first launch the menu bar shows `☀️ — W`: the app does not yet know your SolarFlow's address. Setup takes a minute.

## Finding the SolarFlow on the network

1. Click the ☀️ icon, then the gear (**Settings**), **Device** tab.
2. Click **Search on the network**. The app browses the network over Bonjour/mDNS and lists the Zendure devices it finds (names like `Zendure-solarFlow2400Pro-…`).
3. Click **Use** next to the discovered device, then **Test connection**. On success, the green line shows "Connected", the current production, the battery level and the serial number.

![Device settings tab](../images/settings-device.png)

*The Device tab: network discovery, connection test and refresh interval.*

### Manual entry

If you know the battery's address, type it directly into the **IP address or hostname** field: an IP (`192.168.1.xx`) or a Bonjour name (`Zendure-….local`). A fixed IP (a DHCP reservation on your router) is recommended for stability.

### Discovery finds nothing?

- Check that the Mac and the SolarFlow are on the **same network** (beware of guest networks and Wi-Fi isolation).
- The local API may be disabled on your unit. In the Zendure mobile app, add a **HEMS** integration and then quit it: this is the documented way to persistently enable the local API.

## The macOS "local network" permission

macOS gates access to the local network: Zendure Monitor must be allowed in **System Settings → Privacy & Security → Local Network**. The app checks this and shows an orange "Local network access blocked?" banner in the panel when connection failures look like a denial, with an **Open settings…** button and a **Retry** button.

If the block persists after toggling the switch off and on, restart the Mac. The specific case of the permission getting lost after an **app update** is covered in the [FAQ](faq.md#the-local-network-permission-disappeared-after-an-update).

> Good to know: this permission does not apply to VPN interfaces. If the battery answers over Tailscale but not over local Wi-Fi, this permission is the likely culprit.

## Refresh interval

Still in the **Device** tab, the **Refresh** slider sets how often the battery is polled, from **2 to 60 seconds** (default 5 s). Each poll transfers only about 2 KB of JSON, so the default suits most setups.

Once connected, the menu bar shows the live production (e.g. `☀️ 842 W`) and the panel fills up. Menu bar display options are described in [The panel](panel.md#menu-bar-options).

---

[← Installation](installation.md) | [Index](../README.md) | [The panel →](panel.md)
