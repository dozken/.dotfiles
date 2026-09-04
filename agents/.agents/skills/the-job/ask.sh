#!/usr/bin/env bash
# the-job → Telegram Ask (closed-option question) + Ledger entry. Terms: CONTEXT.md; expiry: docs/adr/0003.
# New ask:  ask.sh <unit> <question with numbered options>     → prints the Code
# Re-ask:   ask.sh --reask <code>
# Exit: 0 sent · 1 config/send failure (caller bails) · 2 budget/limit refused (caller bails)
set -euo pipefail

STATE="$HOME/.claude/skills/the-job/state"
LEDGER="$STATE/ledger"
mkdir -p "$LEDGER"
command -v jq >/dev/null || { echo "ask.sh: jq required" >&2; exit 1; }

ENV_FILE="$HOME/.claude/channels/telegram/.env"
ACCESS_FILE="$HOME/.claude/channels/telegram/access.json"
TOKEN="$(grep -E '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' | tr -d '[:space:]')"
CHAT_ID="${THE_JOB_TG_CHAT:-$(grep -oE '"[0-9]{4,}"' "$ACCESS_FILE" 2>/dev/null | head -1 | tr -d '"')}"
[ -z "$TOKEN" ] || [ -z "$CHAT_ID" ] && { echo "ask.sh: no telegram token/chat — cannot ask, bail instead" >&2; exit 1; }

ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EPOCH=$(date +%s)

# Plain text on purpose: Markdown parse errors would 400 the send, and an undelivered Ask must be loud.
send() {
  local resp
  resp=$(curl -s -m 15 "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=$1" \
    --data-urlencode "disable_web_page_preview=true") || { echo "ask.sh: send failed (network)" >&2; return 1; }
  [ "$(printf '%s' "$resp" | jq -r .ok)" = "true" ] || { echo "ask.sh: send rejected: $resp" >&2; return 1; }
}

if [ "${1:-}" = "--reask" ]; then
  CODE="${2:?usage: ask.sh --reask <code>}"
  F="$LEDGER/$CODE.json"
  [ -f "$F" ] || { echo "ask.sh: no ledger entry $CODE" >&2; exit 1; }
  [ "$(jq -r .status "$F")" = "open" ] || { echo "ask.sh: $CODE is not open" >&2; exit 2; }
  [ "$(jq '.asks | length' "$F")" -ge 2 ] && { echo "ask.sh: re-ask limit reached for $CODE" >&2; exit 2; }
  UNIT=$(jq -r .unit "$F")
  Q=$(jq -r .question "$F")
  send "❓ the-job re-ask [$CODE] — $UNIT
$Q
Reply: $CODE <option>"
  jq --arg iso "$ISO" --argjson ep "$EPOCH" \
     '.asks += [$iso] | .asksEpoch += [$ep] | .coverageSinceLastAsk = 0' \
     "$F" > "$F.tmp" && mv "$F.tmp" "$F"
  echo "$CODE"
  exit 0
fi

UNIT="${1:?usage: ask.sh <unit> <question>}"; shift
QUESTION="${*:?usage: ask.sh <unit> <question>}"

# Ask budget: max 2 Asks per unit, any status. Third wall on one unit is a defect → bail, not ask.
N=0
for f in "$LEDGER"/*.json; do
  [ -e "$f" ] || continue
  [ "$(jq -r .unit "$f")" = "$UNIT" ] && N=$((N+1))
done
[ "$N" -ge 2 ] && { echo "ask.sh: ask budget exhausted for $UNIT (2) — bail" >&2; exit 2; }

# Code: 5 lowercase chars, exactly one digit at a random slot — structurally immune to the telegram
# plugin's permission regex (^(y|yes|n|no)\s+[a-km-z]{5}$) which silently eats matching replies.
gen_code() {
  local letters=abcdefghjkmnpqrstuvwxyz digits=23456789 pos=$((RANDOM % 5)) c="" i
  for i in 0 1 2 3 4; do
    if [ "$i" -eq "$pos" ]; then c="$c${digits:RANDOM % ${#digits}:1}"; else c="$c${letters:RANDOM % ${#letters}:1}"; fi
  done
  printf '%s' "$c"
}
CODE=$(gen_code)
while [ -e "$LEDGER/$CODE.json" ]; do CODE=$(gen_code); done

jq -n --arg code "$CODE" --arg unit "$UNIT" --arg q "$QUESTION" --arg iso "$ISO" --argjson ep "$EPOCH" \
  '{code: $code, unit: $unit, question: $q, asks: [$iso], asksEpoch: [$ep],
    coverageSinceLastAsk: 0, status: "open", reply: null, createdAt: $iso}' \
  > "$LEDGER/$CODE.json"

if ! send "❓ the-job ask [$CODE] — $UNIT
$QUESTION
Reply: $CODE <option>"; then
  rm -f "$LEDGER/$CODE.json"   # never leave a ledger entry that was never delivered
  exit 1
fi
echo "$CODE"
