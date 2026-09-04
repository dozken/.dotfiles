#!/usr/bin/env bash
# the-job tick-start mechanics: coverage accounting → read-only Drain → Inbox→Ledger binding.
# Prints one action-summary JSON; touches nothing outside state/. Terms: CONTEXT.md; ADRs 0001-0003.
set -euo pipefail

STATE="$HOME/.claude/skills/the-job/state"
INBOX="$STATE/inbox"; LEDGER="$STATE/ledger"; SEEN="$STATE/seen"
mkdir -p "$INBOX" "$LEDGER" "$SEEN"
command -v jq >/dev/null || { echo '{"error":"jq required"}'; exit 1; }

NOW=$(date +%s)
ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ---- 1. Coverage accounting (ADR 0003): a tick contributes min(gap, 24h) of listening coverage.
PREV=$(cat "$STATE/last-tick" 2>/dev/null || echo "")
GAP=0; RESUMED=false; ADD=0
if [ -n "$PREV" ]; then
  GAP=$((NOW - PREV))
  [ "$GAP" -gt 86400 ] && RESUMED=true   # a >24h gap can have expired replies at Telegram unseen
  ADD=$GAP; [ "$ADD" -gt 86400 ] && ADD=86400
fi
printf '%s' "$NOW" > "$STATE/.last-tick.tmp" && mv "$STATE/.last-tick.tmp" "$STATE/last-tick"

for f in "$LEDGER"/*.json; do
  [ -e "$f" ] || continue
  if [ "$ADD" -gt 0 ] && [ "$(jq -r .status "$f")" = "open" ]; then
    jq --argjson add "$ADD" '.coverageSinceLastAsk += $add' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi
done

# ---- 2. Drain (ADR 0001: read-only, NO offset ever; ADR 0002: only when no live poller).
DRAINED=0; DRAIN_NOTE="drained"; POLLER=false
BOTPID_FILE="$HOME/.claude/channels/telegram/bot.pid"
if [ -f "$BOTPID_FILE" ]; then
  BOTPID=$(cat "$BOTPID_FILE" 2>/dev/null || echo "")
  if [ -n "$BOTPID" ] && kill -0 "$BOTPID" 2>/dev/null \
     && ps -p "$BOTPID" -o command= 2>/dev/null | grep -qiE 'telegram|server\.ts'; then
    POLLER=true; DRAIN_NOTE="live poller pid=$BOTPID — Capture path owns replies"
  fi
fi

if [ "$POLLER" = false ]; then
  LOCK="$STATE/drain.lock.d"; HOLD=false
  if mkdir "$LOCK" 2>/dev/null; then
    HOLD=true
  else
    LOCKPID=$(cat "$LOCK/pid" 2>/dev/null || echo "")
    if [ -n "$LOCKPID" ] && kill -0 "$LOCKPID" 2>/dev/null; then
      DRAIN_NOTE="another tick is draining (pid $LOCKPID)"
    else
      rm -rf "$LOCK"
      mkdir "$LOCK" 2>/dev/null && HOLD=true || DRAIN_NOTE="lost lock race"
    fi
  fi
  if [ "$HOLD" = true ]; then
    printf '%s' $$ > "$LOCK/pid"
    ENV_FILE="$HOME/.claude/channels/telegram/.env"
    TOKEN=$(grep -E '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' | tr -d '[:space:]')
    CHAT="${THE_JOB_TG_CHAT:-$(grep -oE '"[0-9]{4,}"' "$HOME/.claude/channels/telegram/access.json" 2>/dev/null | head -1 | tr -d '"')}"
    if [ -z "$TOKEN" ] || [ -z "$CHAT" ]; then
      DRAIN_NOTE="no token/chat configured — Asks unavailable on this box"
    else
      RESP=$(curl -s -m 15 -w '\n%{http_code}' "https://api.telegram.org/bot${TOKEN}/getUpdates?timeout=0&limit=100" || printf '\n000')
      HTTP=$(printf '%s' "$RESP" | tail -1)
      BODY=$(printf '%s' "$RESP" | sed '$d')
      if [ "$HTTP" = "200" ]; then
        COUNT=$(printf '%s' "$BODY" | jq '.result | length')
        i=0
        while [ "$i" -lt "$COUNT" ]; do
          U=$(printf '%s' "$BODY" | jq -c ".result[$i]"); i=$((i+1))
          MID=$(printf '%s' "$U" | jq -r '.message.message_id // empty')
          CID=$(printf '%s' "$U" | jq -r '.message.chat.id // empty')
          TYPE=$(printf '%s' "$U" | jq -r '.message.chat.type // empty')
          TEXT=$(printf '%s' "$U" | jq -r '.message.text // .message.caption // empty')
          if [ -z "$MID" ] || [ "$TYPE" != "private" ] || [ "$CID" != "$CHAT" ] || [ -z "$TEXT" ]; then continue; fi
          WM=$(cat "$SEEN/$CID" 2>/dev/null || echo 0)
          if [ "$MID" -le "$WM" ]; then continue; fi
          DST="$INBOX/${CID}-${MID}.json"   # idempotent filename = free dedup across re-deliveries
          printf '%s' "$U" | jq '{chat_id: .message.chat.id, message_id: .message.message_id,
            user_id: .message.from.id, ts: (.message.date | todate),
            text: (.message.text // .message.caption), via: "drain"}' > "$DST.tmp" && mv "$DST.tmp" "$DST"
          DRAINED=$((DRAINED+1))
        done
      else
        DRAIN_NOTE="getUpdates HTTP $HTTP — a poller likely booted; skipped (no retry, no offset)"
      fi
    fi
    rm -rf "$LOCK"
  fi
fi

# ---- 3. Bind Inbox → Ledger (reply's first token = Code; watermark on consume).
ANSWERED="[]"; LATE="[]"; UNBOUND="[]"
for f in "$INBOX"/*.json; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in .*) continue;; esac
  CID=$(jq -r .chat_id "$f"); MID=$(jq -r .message_id "$f"); TEXT=$(jq -r .text "$f"); VIA=$(jq -r '.via // "capture"' "$f")
  WM=$(cat "$SEEN/$CID" 2>/dev/null || echo 0)
  if [ "$MID" -le "$WM" ]; then rm -f "$f"; continue; fi
  TOK=$(printf '%s' "$TEXT" | awk '{print tolower($1)}')
  if [ "$(printf '%s' "$TEXT" | wc -w | tr -d ' ')" -ge 2 ]; then
    REST=$(printf '%s' "$TEXT" | sed -E 's/^[^ ]+ +//')
  else
    REST=""
  fi
  if printf '%s' "$TOK" | grep -qE '^[a-z0-9]{5}$' && printf '%s' "$TOK" | grep -q '[0-9]' && [ -f "$LEDGER/$TOK.json" ]; then
    L="$LEDGER/$TOK.json"
    ST=$(jq -r .status "$L")
    if [ "$ST" = "open" ] || [ "$ST" = "expired" ]; then
      jq --arg t "$REST" --arg ts "$ISO" --arg via "$VIA" \
         '(if .status == "open" then .status = "answered" else . end) | .reply = {text: $t, ts: $ts, via: $via}' \
         "$L" > "$L.tmp" && mv "$L.tmp" "$L"
      E=$(jq -c '{code, unit, reply: .reply.text}' "$L")
      if [ "$ST" = "open" ]; then ANSWERED=$(printf '%s' "$ANSWERED" | jq -c --argjson e "$E" '. + [$e]')
      else LATE=$(printf '%s' "$LATE" | jq -c --argjson e "$E" '. + [$e]'); fi
    fi
    rm -f "$f"
    printf '%s' "$MID" > "$SEEN/$CID.tmp" && mv "$SEEN/$CID.tmp" "$SEEN/$CID"
  else
    UNBOUND=$(printf '%s' "$UNBOUND" | jq -c --arg file "$(basename "$f")" --arg text "$(printf '%.120s' "$TEXT")" '. + [{file: $file, text: $text}]')
  fi
done

# ---- 4. Re-ask / expiry actions (ADR 0003): agent executes these, the script only computes.
REASK="[]"; EXPIRE="[]"; OPEN="[]"
for f in "$LEDGER"/*.json; do
  [ -e "$f" ] || continue
  [ "$(jq -r .status "$f")" = "open" ] || continue
  E=$(jq -c --argjson now "$NOW" --argjson resumed "$([ "$RESUMED" = true ] && echo true || echo false)" \
    '{code, unit, asksCount: (.asks | length), coverageH: ((.coverageSinceLastAsk / 3600) | floor),
      wallH: ((($now - .asksEpoch[0]) / 3600) | floor),
      reaskDue: ((.asks | length) == 1 and ($resumed or .coverageSinceLastAsk >= 86400)),
      expireDue: ((.asks | length) >= 2 and .coverageSinceLastAsk >= 86400 and ($now - .asksEpoch[0]) >= 259200)}' "$f")
  OPEN=$(printf '%s' "$OPEN" | jq -c --argjson e "$E" '. + [$e]')
  [ "$(printf '%s' "$E" | jq .reaskDue)" = "true" ] && REASK=$(printf '%s' "$REASK" | jq -c --argjson e "$E" '. + [$e]')
  [ "$(printf '%s' "$E" | jq .expireDue)" = "true" ] && EXPIRE=$(printf '%s' "$EXPIRE" | jq -c --argjson e "$E" '. + [$e]')
done

jq -n --argjson resumed "$([ "$RESUMED" = true ] && echo true || echo false)" \
  --argjson gap "$GAP" --argjson pollerLive "$([ "$POLLER" = true ] && echo true || echo false)" \
  --argjson drained "$DRAINED" --arg drainNote "$DRAIN_NOTE" \
  --argjson answered "$ANSWERED" --argjson lateReplies "$LATE" --argjson unbound "$UNBOUND" \
  --argjson reaskDue "$REASK" --argjson expireDue "$EXPIRE" --argjson openAsks "$OPEN" \
  '{resumedAfterGap: $resumed, gapSeconds: $gap, pollerLive: $pollerLive, drained: $drained,
    drainNote: $drainNote, answered: $answered, lateReplies: $lateReplies, unbound: $unbound,
    reaskDue: $reaskDue, expireDue: $expireDue, openAsks: $openAsks}'
