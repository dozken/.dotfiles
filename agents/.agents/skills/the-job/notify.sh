#!/usr/bin/env bash
# the-job → Telegram progress ping. Usage: notify.sh "<message>"
# Reads bot token from the telegram channel .env; chat_id = the allowlisted user.
set -euo pipefail

MSG="${1:-}"
[ -z "$MSG" ] && { echo "notify.sh: empty message" >&2; exit 0; }

ENV_FILE="$HOME/.claude/channels/telegram/.env"
ACCESS_FILE="$HOME/.claude/channels/telegram/access.json"

# Token
TOKEN="$(grep -E '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' | tr -d '[:space:]')"
[ -z "${TOKEN:-}" ] && { echo "notify.sh: no telegram token, skipping" >&2; exit 0; }

# Chat id: THE_JOB_TG_CHAT env override, else first allowlisted id
CHAT_ID="${THE_JOB_TG_CHAT:-}"
if [ -z "$CHAT_ID" ]; then
  CHAT_ID="$(grep -oE '"[0-9]{4,}"' "$ACCESS_FILE" 2>/dev/null | head -1 | tr -d '"')"
fi
[ -z "${CHAT_ID:-}" ] && { echo "notify.sh: no chat id, skipping" >&2; exit 0; }

# Non-fatal: a failed ping must never break the job.
curl -s --max-time 10 "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  --data-urlencode "parse_mode=Markdown" \
  --data-urlencode "disable_web_page_preview=false" >/dev/null 2>&1 || \
  echo "notify.sh: telegram send failed (ignored)" >&2
exit 0
