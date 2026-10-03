## Reserve, maximum charge and surplus feed-in

The **Control** tab of the settings gains a *Reserve, charge and feed-in* section:

- **Reserve** (0–50 %): the battery does not discharge below this level.
- **Maximum charge** (70–100 %).
- **Surplus feed-in** — *allowed* or *forbidden*. When forbidden (a common factory setting), a full battery makes the SolarFlow curtail its panels and the production is lost; when allowed, the surplus flows to the grid.

Settings can target one device or **all devices** at once, and each device's current values are shown, so you can see the command land.

## Two safeguards

- **Enabling feed-in asks for confirmation.** In France, feeding into the public grid requires a self-consumption agreement with Enedis (CACSI), and a purchase contract to be paid for it.
- **A reserve above a battery's current level asks for confirmation too.** The firmware reacts by charging the battery **from the grid, immediately, at full power** — about 2.4 kW per SolarFlow 2400 Pro. We found out on a real installation: two units at 10 % given a 20 % reserve drew 4.8 kW from the grid within seconds. The dialog now says so; the safe way is to raise the reserve when the battery is above it.

## Also

- The per-device dashboard card shows whether surplus feed-in is allowed.
- Values are written in tenths of a percent, the same scale as the official Zendure Home Assistant integration.
- In *smartMode* (the usual case) the device does not store these values permanently — they are lost when it restarts. For a lasting setting, also set it once in the Zendure app.
- Full French and English localization.
