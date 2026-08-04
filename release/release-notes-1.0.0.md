## Zendure Monitor 1.0.0

First public release 🎉

macOS menu bar app showing the live solar production of a Zendure SolarFlow battery — 100% local (zenSDK REST API), no cloud account, no MQTT broker.

### Features
- Live solar production in the menu bar (W / kW), refresh every 2–60 s
- Detail panel: battery state of charge with charge/discharge power, output to home, grid input, per-MPPT PV inputs
- Bonjour discovery of the device — browses both `_zendure._tcp` (documented) and `_http._tcp` (what SolarFlow 2400 Pro firmwares actually advertise)
- Settings: host/IP, poll interval, network scan, connection test
- Auto-updates via Sparkle 2 (EdDSA-signed)

### Requirements
- macOS 14 Sonoma or later
- A Zendure device with the local zenSDK API (SolarFlow 2400 AC/AC+/Pro, 800, 1600 AC+, 3000/4000 Mix). If discovery finds nothing, enable the local API from the Zendure app: add a HEMS integration, then quit it.

Signed with a Developer ID certificate and notarized by Apple.
