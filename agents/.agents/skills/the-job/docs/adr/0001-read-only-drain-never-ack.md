# Drain never acknowledges getUpdates

The Drain calls `getUpdates` with `timeout=0` and **no offset parameter — ever**. Telegram confirms (irreversibly destroys) every update below any offset sent, and the shared token also carries pairing replies, permission replies, and ordinary chat meant for live sessions; acking from the-job would silently destroy them with no history API to recover. Cost: the same replies are re-delivered to the next live poller — made inert by the per-chat Watermark, and self-expiring via Telegram's 24h retention.

## Consequences

- Only the earliest ≤100 unconfirmed updates are visible per Drain — acceptable at this traffic.
- Any 409 during a Drain means a poller just booted: release the mutex and stop, so a booting session's server is never starved into its 8-strike give-up.
