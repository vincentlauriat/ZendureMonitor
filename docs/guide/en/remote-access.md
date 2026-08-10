---
title: Remote access
---

[🇫🇷 Version française](../fr/acces-distant.md)

# Remote access (away from home)

The SolarFlow's local API only exists on your home network, and it has **no authentication whatsoever**.

> ⚠️ **Never expose the SolarFlow's port 80 directly to the internet** (no port forwarding on the router): anyone could read the battery's state and send it commands. The safe pattern is a VPN into your home.

## The recommended pattern: Tailscale or WireGuard VPN

1. Install [Tailscale](https://tailscale.com) (or WireGuard) on a machine that stays home — a Mac, a NAS, a Raspberry Pi or the router — and enable **subnet routing** for your LAN (e.g. `192.168.68.0/24`).
2. Install Tailscale on your Mac. When away, the SolarFlow's LAN IP stays reachable through the tunnel.
3. In **Settings → Remote**, set that reachable address as the **fallback host** (e.g. the battery's LAN IP routed by the subnet router, or a Tailscale `100.x.y.z` IP if you expose the device another way).

![Remote settings tab](../images/settings-remote.png)

*The Remote tab: fallback host and 24/7 history server.*

## How the fallback host is used

- The app polls the **primary (local) address** first. If it does not answer, the app switches to the fallback host automatically — the panel shows "Connected via the fallback host" and the dashboard shows "Connection: fallback host".
- Once switched, the app **stays** on the fallback and only retests the primary address **every 2 minutes**: refreshes do not pay a timeout on every poll while you are away.

## Limitation: `.local` names do not cross the tunnel

Bonjour/mDNS names (`Zendure-….local`) only resolve on the local network: **through a VPN, use the battery's IP address**, not its `.local` name. That is also why the fallback host is usually entered as an IP. A DHCP reservation on the router guarantees that IP never changes.

## The optional 24/7 collector

Today's energy and the history are normally accumulated by the app: when the Mac is off or asleep, those hours are missing. For a complete history, a small **collector** (the project's `Scripts/collector` folder) can run on an always-on machine:

- a Python script (standard library only, Python 3.9+) run as a LaunchAgent, polling the battery continuously, integrating daily energy into a SQLite database and serving a tiny JSON API (port 8899 by default);
- in **Settings → Remote**, fill in **24/7 history server** as `host:port` (e.g. `minicorse.local:8899`);
- the app then displays the collector's history (green "24/7 collector" badge on the dashboard's History card) and keeps the best of both counts for each day.

## What if the VPN goes down?

Since 1.11, the [Cloud mode](cloud.md#automatic-switching-new-in-111) can take over **automatically**: with the "Basculer automatiquement" option enabled and a Cloud Key saved, the app switches itself to Cloud when the SolarFlow stops answering locally (VPN down, gateway asleep…) and comes back to local as soon as it answers again. The VPN remains useful for battery control and the Smart CT, both local-only.

---

[← Alerts and savings](alerts.md) | [Index](../README.md) | [FAQ and troubleshooting →](faq.md)
