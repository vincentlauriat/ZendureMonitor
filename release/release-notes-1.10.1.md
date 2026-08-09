# ZendureMonitor 1.10.1

## Fixed — discovered devices you can actually use, and a cleaner flow diagram

- **Bonjour discovery now returns the device's IPv4 address instead of its `.local` hostname.** On some networks, resolving a `.local` name through getaddrinfo takes ~5 s (a silent AAAA query) — just above the app's 5 s request timeout, so a device found by discovery was then unusable for testing or polling, while the same call by IP answers in tens of milliseconds. The resolved address was already in the Bonjour response; the app now uses it directly, falling back to the hostname only when no IPv4 is available. If a DHCP lease ever changes the address, run "Search the network" again.
- **Energy-flow diagram is now planar — no flow ever crosses another.** The grid → home link used to arc under the SolarFlow hub, cutting across the vertical battery link. Grid and Home now sit adjacent on the right column (home on top, grid below — the meter physically sits between them), so their direct link is a straight vertical segment along the edge, out of every other flow's way. The off-grid outlet moves to the bottom-left corner, and node labels are placed above or below each badge so no text sits on a link.

## Under the hood

- `DeviceDiscovery.ipv4Address(from:)` extracts the first IPv4 from the raw `sockaddr` list (IPv6 and truncated data ignored, unit-tested).
- `EnergyFlowView` label placement is now explicit per node (`below` / `above` / `titleAbove`); the measured grid → home case reuses the standard animated link, the unmeasured case keeps its grey "not measured" tag.
- 85 tests, all green. Rendering verified light/dark, with and without a Smart CT, outlet active or not.

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
