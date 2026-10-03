## Several SolarFlow, one installation

ZendureMonitor was built around a single SolarFlow. Add a second one and the app simply did not see it. 2.3 makes multi-device a first-class setup.

**Settings → Device** is now an address list. *Search the network* offers an **Add** button for every SolarFlow it finds (the Smart CT, which announces itself the same way, is left out — it has its own section). Your existing address is migrated automatically.

All devices are polled **in parallel** — a unit that is switched off does not add its 5-second timeout to every refresh — and the whole app shows the **installation**: menu bar, energy flow, Sankey, widget, daily energy and history all use the sum. State of charge is the average over all battery packs.

A new **Devices** card shows each unit's share: solar input, state of charge with charge/discharge flow, and output to the house. In the dashboard it goes further — PV inputs, temperature, Wi-Fi signal, AC mode, charge/output limits and charge range — the values that belong to one device and have no meaning on a sum.

## Honest when something is missing

- If one device stops answering, a warning says so and the totals are flagged **partial**. They never quietly shrink to look like the full picture.
- **Low-battery and full-battery alerts are evaluated per device.** One unit at 10 % next to another at 100 % averages 55 % — that must still alert, and now it does, naming the unit.
- The zero-production-in-daylight alert is per device as well, and a dedicated notification tells you when one unit goes silent while the others keep reporting.

## Also

- **Cloud mode** aggregates every device of the Zendure account the same way (the old *tracked device* picker is gone).
- **Battery control** always targets one named device through a picker; a command can never be sent “to the sum”.
- The VPN fallback host applies to the first device; automatic switching to Cloud now happens only when *every* device is unreachable.
- Single-device setups see no change — same values, same notifications.
- Full French and English localization.
