## The energy flow, now readable two ways

The dashboard's energy-flow card gained a **Schéma / Sankey** picker. Same flows, same numbers, same colours — only the reading changes, and your choice is remembered.

**Schematic** is what you already know: the SolarFlow at the centre, panels, batteries, public grid, home and the off-grid outlet around it, each link animating only when energy actually flows. It shows the **topology** of your installation — what is wired to what.

**Sankey** makes the width of each ribbon the wattage. Sources on the left, the SolarFlow in the middle, uses on the right. That single change surfaces proportions the schematic cannot express with constant-width links: how much of your production goes straight to the house versus into the battery, and — the striking one — **how much of your consumption never passes through the SolarFlow at all**. On a winter evening you see the grid band dwarf everything while the SolarFlow shrinks to the few hundred watts actually crossing it.

## Two things the Sankey refuses to fake

A Sankey diagram makes a visual claim that an animated schematic does not: that everything entering comes back out. Two consequences were handled explicitly rather than papered over.

- **The hub never balances exactly** — conversion losses, measurement noise. Instead of quietly absorbing the difference into the other ribbons, it is drawn as its own grey ribbon: *“Pertes & conversion”* when more goes in than comes out, *“Écart de mesure”* the other way round. Both columns then have the same height by construction, which is the honest way to close the picture.
- **Without a Smart CT, the home's direct grid draw is real but unmeasured.** Giving it a proportional width would invent a number; leaving it out would assert it is zero. It keeps a **fixed-width hatched band**, off scale, marked *“non mesuré”* — and the same hatched cap sits on top of the Home node's bar, so the bar visibly says “there is more here, and we don't know how much”.

## Also

- The Sankey carries everything the schematic showed: state of charge and per-pack SOC on the Batteries node, device temperature under the SolarFlow bar.
- Flow direction and intensity are animated the same way as in the schematic — dashes running along each ribbon at a speed tied to its wattage.
- Full French and English localization, as always.

Nothing else changed: same local-first polling, same Cloud mode, same SunRoad, same History window.
