# The History window

*New in 1.12.*

Until now the app only knew what it had seen itself (or through the 24/7 collector). The **History window** fetches your daily energy **from Zendure's servers** — up to **365 days** back, including periods when your Mac was off.

Open it with the **purple clock** in the panel header.

## Signing in with your Zendure account

The history comes from the private API of the Zendure mobile app — the only known path to this data. It requires the **e-mail and password of your main Zendure account** (the ones you use in the phone app): the Cloud Key from [Cloud mode](cloud.md) is not enough.

- Credentials are stored **only in the macOS Keychain**, on a path fully separate from the Cloud Key.
- The **Sign out** button wipes them from the Keychain at any time.
- Cloud mode is not required: the history works in **local mode** just as well.

## What the window shows

One card per device on the account (SolarFlow Hub, Hyper…), each with:

- a **bar chart** of the daily energy (kWh) over **7 / 30 / 90 / 365 days** (selector at the top of the window);
- a **per-device metric list**: each product reports its own set of fields (solar, home, battery charge/discharge, grid, AC/DC output…) — the picker only offers what *your* device actually returns, and the choice is remembered per device;
- **period total, daily average and best day** under the chart;
- the device's **lifetime totals**.

## Local cache and request pacing

Past days are immutable: once fetched they are **cached on your Mac** and never downloaded again — only the current day is refreshed. The first 365-day load takes about a minute (requests are deliberately spaced out to go easy on Zendure's servers); after that, refreshing is near-instant.

## The Debug card

At the bottom of the window, the **Debug card** lists the last HTTP exchanges with the API (password redacted): status, request and raw response, expandable and copyable. It is the first place to look if the connection fails.

## Good to know

This API is **not contractual**: field names and units (assumed Wh) come from community observations (the FHEM Zendure module, solarflow-statuspage). Zendure may change it without notice — the Debug card is there to understand what changed if it ever does.

---

[← The Sun window](sun.md) | [Index](../README.md) | [Widgets →](widgets.md)
