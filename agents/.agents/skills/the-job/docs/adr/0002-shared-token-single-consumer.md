# One shared bot token, routed by consumer

the-job reuses the telegram plugin's bot token and routes by who holds the poll: a liveness-checked live poller means Capture (that session appends the `<channel>` reply to the Inbox); no poller means Drain. A dual-writer hook design was rejected because no hook event fires for channel messages (`UserPromptSubmit` does not — they are MCP notifications, not prompts), and a live poller's consumption is irreversible, so no amount of pid coordination recovers a reply it ate.

## Considered Options

- **Second BotFather token owned by the-job** — cleanest isolation (own getUpdates slot, no Capture instruction, no routing), rejected for now: one more bot to create and pair, and asks would come from a different Telegram contact than progress pings. Re-open this if Capture proves unreliable in practice — it is the known-weak link (depends on live sessions following a global instruction, backstopped by re-ask).
- **Dual-writer (hook + drain)** — rejected: the hook cannot exist; see above.
