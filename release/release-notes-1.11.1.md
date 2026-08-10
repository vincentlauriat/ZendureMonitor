# ZendureMonitor 1.11.1

## Fixed — clearer diagnostics for Cloud-mode MQTT drops

Following a report from a user with two SolarFlows stuck in an endless *"MQTT connection lost: connection closed by the server — reconnecting in 15 s"* loop:

- **Session-takeover detection.** The Zendure cloud allows a **single real-time session per Cloud Key** — two clients (this app plus Home Assistant, ioBroker, or the app on another Mac) kick each other off in a loop. The app now detects that pattern (repeated server closes right after connecting) and says so explicitly, instead of showing a generic error that looks like an app bug.
- **Subscription refusals are now visible.** The MQTT client reads the broker's SUBACK return codes; if every subscription is denied, the session fails with *"subscriptions refused by the server"* rather than sitting on a silent feed.
- **Malformed-topic guard.** Device-list entries with an empty deviceKey/productKey are ignored — subscribing to a malformed topic can get the connection closed by the broker.

If you hit the loop: check whether another integration (Home Assistant, ioBroker, another Mac) uses the same Authorization Cloud Key, and keep only one connected at a time.

---

Auto-update via Sparkle: the app offers this update by itself. Manual download below.
