# Cloud mode and the Smart CT meter

*New in 1.10.*

## The Zendure Cloud mode

By default the app reads the SolarFlow **locally** (zenSDK API on your network) — the recommended mode: faster, and independent of the Internet. Cloud mode is a second path, useful when the local API is unreachable (device dropped off the Wi-Fi, Mac away from home without a VPN).

### Enabling Cloud mode

1. In the Zendure mobile app, with the **main account**: *Profile → "Authorization Cloud Key"* (depending on the version: *Settings → Developer*). Copy the key.
2. In Zendure Monitor: *Settings → Device*, switch "Data source" to **Zendure Cloud**.
3. Paste the key, "Test the key" (your device list shows up), then "Save and connect".
4. The status goes through "Connecting to the Zendure account…" → "Connecting to the real-time feed…" → **"Connected — real-time data"**.

Data then arrives in **real time over MQTT** from Zendure's servers, wherever you are — no VPN needed. History, daily counters, outage alerts and widgets work exactly as in local mode. The bottom of the panel always shows which path is in use (local — primary / fallback host, or Cloud).

### Worth knowing

- **The key stays on your Mac**: it is kept in the macOS Keychain and only serves to obtain the MQTT credentials from Zendure. The raw token never leaves the machine.
- **Read-only**: the Control tab is disabled in Cloud mode. To drive the battery (AC mode, limits), switch back to the Local API mode.
- A **shared** account does not work (empty device list): use the main account's key.
- If the feed drops, the app reconnects by itself (a full new session in ~15 s).

## The Smart CT meter

If a **Zendure SmartMeter3CT** sits in your electrical panel, the app can show what the SolarFlow cannot know: the home's **real draw from the public grid** and its **total consumption**.

1. *Settings → Network → "Smart CT meter"*: click **"Detect on the network"** (the meter advertises over Bonjour, like the SolarFlow), then "Use" and "Test".
2. In the dashboard, the **Grid → Home** arc of the flow diagram becomes a real measured flow (animated, with its wattage), and the Home node shows the total consumption (grid + SolarFlow output). The note under the diagram details the three phases.

The Smart CT is queried **locally only** — the Zendure cloud does not relay its readings. Away from home (without a VPN), the arc honestly falls back to "not measured" rather than freezing a stale number.

---

← [Remote access](remote-access.md) · [FAQ and troubleshooting](faq.md) →
