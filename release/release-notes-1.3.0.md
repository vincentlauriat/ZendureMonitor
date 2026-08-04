## Zendure Monitor 1.3.0

### New
- **macOS widget** 🧩 — small & medium widgets showing live solar production, battery level, home output, today's energy and a mini trend curve (Notification Center / desktop). Data is shared by the app through an App Group container.
- **Battery control** 🎛 — new "Control" tab in Settings: AC mode (charge from grid / discharge to home), output limit and charge limit, sent to the device via `POST /properties/write` (with an explicit warning — these commands drive the real battery).
- **CSV export** 📄 — export the daily production history (up to 90 days) from the History card.

### Notes
- The widget needs the app to be running (it reads the app's snapshot; it does not poll the device itself).
- macOS 14+, signed and notarized. Auto-update via Sparkle.
