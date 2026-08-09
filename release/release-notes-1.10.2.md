# ZendureMonitor 1.10.2

## Changed — a symmetric energy-flow diagram

- **The flow diagram is now a symmetric X around the SolarFlow.** Panels (top) and the battery gauge (bottom) sit on the left column, mirroring Home (top) and Grid (bottom) on the right — sources and storage feed the hub from the left, the hub feeds the home on the right, and the grid → home link stays a straight vertical segment along the right edge. The off-grid outlet now hangs directly below the hub while it delivers. The diagram remains planar: no flow ever crosses another.

## Under the hood

- Layout-only change in `EnergyFlowView`; measurement logic, animations and the "not measured" honesty rule are untouched.
- 85 tests, all green. Rendering verified light/dark, with and without a Smart CT, outlet active or not.

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
