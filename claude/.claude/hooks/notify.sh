#!/usr/bin/env bash
# Claude Code notify hook. Routes events -> ntfy (phone) + macOS (local).
# Wired to Notification + Stop hooks in settings.json.
set -euo pipefail

NTFY_TOPIC="claude-4dace2c3a6686779be13c522"   # secret = your inbox. anyone with it can read.
NTFY_SERVER="https://ntfy.sh"

# Hook event name passed as $1. Payload JSON on stdin.
EVENT="${1:-event}"
PAYLOAD="$(cat || true)"

# Pull message from payload; fall back to event name.
MSG="$(printf '%s' "$PAYLOAD" | jq -r '.message // empty' 2>/dev/null || true)"
[ -z "$MSG" ] && MSG="$EVENT"

# Locate the source: tmux session:window, else hostname.
if [ -n "${TMUX:-}" ]; then
  LOC="$(tmux display-message -p '#S:#I:#W' 2>/dev/null || echo tmux)"
else
  LOC="$(hostname -s 2>/dev/null || echo local)"
fi

# Per-event tone.
case "$EVENT" in
  Stop)         TITLE="Claude done"; PRIO="default"; TAGS="white_check_mark" ;;
  Notification) TITLE="Claude waiting"; PRIO="high"; TAGS="bell" ;;
  *)            TITLE="Claude"; PRIO="default"; TAGS="robot" ;;
esac

# Phone push. Click action jumps nowhere useful on its own, so location goes in body.
curl -fsS \
  -H "Title: ${TITLE} — ${LOC}" \
  -H "Priority: ${PRIO}" \
  -H "Tags: ${TAGS}" \
  -d "${MSG}" \
  "${NTFY_SERVER}/${NTFY_TOPIC}" >/dev/null 2>&1 || true

# Local macOS banner (best effort; silent if unavailable).
if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier -title "${TITLE}" -subtitle "${LOC}" -message "${MSG}" -sound default >/dev/null 2>&1 || true
else
  osascript -e "display notification \"${MSG}\" with title \"${TITLE}\" subtitle \"${LOC}\"" >/dev/null 2>&1 || true
fi

exit 0
