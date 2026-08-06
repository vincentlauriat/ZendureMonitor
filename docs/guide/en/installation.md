---
title: Installation
---

[🇫🇷 Version française](../fr/installation.md)

# Installation

## Requirements

- A Mac running **macOS 14 (Sonoma) or later**.
- A **Zendure SolarFlow** battery on the same local network, with a recent firmware that ships the local zenSDK API (tested on a SolarFlow 2400 Pro; the 2400 AC / AC+ / AC Pro, 800 Pro/Plus, 1600 AC+, 3000 Mix AC+ and 4000 Mix models shipping the same API should work).

No Zendure account, no MQTT broker, no API key: everything stays local.

## Download and install

1. Download the latest `ZendureMonitor-x.y.z.dmg` from the [Releases](https://github.com/vincentlauriat/ZendureMonitor/releases/latest) page.
2. Open the DMG and drag **ZendureMonitor.app** into **/Applications**.
3. Launch the app: a ☀️ icon appears in the menu bar, at the top right of the screen.

## Gatekeeper and notarization

The app is **signed with a Developer ID certificate and notarized by Apple**: macOS opens it without any security warning. To verify it yourself:

```bash
spctl -a -t exec -vv /Applications/ZendureMonitor.app
# expected: accepted, source=Notarized Developer ID
```

## First launch: the "local network" permission

On first launch, macOS asks whether Zendure Monitor may **find and connect to devices on your local network**. Accept it: without this permission the app cannot reach the battery. If you declined it (or the permission got lost after an update), see the [FAQ](faq.md#the-local-network-permission-disappeared-after-an-update).

## Automatic updates

Updates are delivered in-app via [Sparkle](https://sparkle-project.org): when a new version is published, the app offers it by itself. You can also check manually: click the ☀️ icon, then the **⋯** button at the top right of the panel → **Check for updates…**.

---

[Index](../README.md) | [Getting started →](getting-started.md)
