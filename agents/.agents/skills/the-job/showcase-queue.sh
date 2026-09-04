#!/usr/bin/env bash
# Cross-session showcase-fix coordinator: FIFO queue + atomic mutex + stale reclaim.
# One recorder at a time across ALL sessions (display/ffmpeg/app are singletons).
#
#   ticket=$(showcase-queue.sh enqueue "6152-dq-tree")   # get in line
#   showcase-queue.sh try-acquire "$ticket"              # 0=my turn+locked, 1=wait
#   ...record...
#   showcase-queue.sh release "$ticket"                  # free the lock
#   showcase-queue.sh status                             # monitor: holder + queue
set -euo pipefail

ROOT="$HOME/.claude/showcase-lock"
LOCK="$ROOT/lock.d"          # atomic mutex (mkdir)
META="$LOCK/holder"          # who holds it: "pid|ticket|label|epoch"
QUEUE="$ROOT/queue"
mkdir -p "$QUEUE"

# A recording is genuinely live if a foreign playwright/ffmpeg is running.
showcase_procs_live() { pgrep -fl "playwright test|/_showcase/|ms-playwright/ffmpeg" 2>/dev/null | grep -v pgrep >/dev/null 2>&1; }
pid_alive() { kill -0 "$1" 2>/dev/null; }

# Drop a held lock whose owner is dead AND with no live recording — prevents a crashed session wedging the queue.
reclaim_if_stale() {
  [ -d "$LOCK" ] || return 0
  local holder pid; holder="$(cat "$META" 2>/dev/null || true)"; pid="${holder%%|*}"
  if [ -n "$pid" ] && ! pid_alive "$pid" && ! showcase_procs_live; then
    rm -rf "$LOCK"; echo "reclaimed stale lock (dead pid $pid)" >&2
  fi
}

front_ticket() { ls "$QUEUE" 2>/dev/null | sort | head -1; }

case "${1:-status}" in
  enqueue)
    label="${2:-showcase}"
    ticket="$(date +%s%N)-$$"          # epoch-ns + pid → total FIFO order
    printf '%s' "$label" > "$QUEUE/$ticket"
    echo "$ticket" ;;

  try-acquire)
    ticket="${2:?ticket required}"
    reclaim_if_stale
    # Not my turn if I'm not the oldest ticket.
    [ "$(front_ticket)" = "$ticket" ] || { echo "waiting — ahead of you: $(front_ticket)" >&2; exit 1; }
    # A foreign (non-queue) recording is running → hold, don't collide.
    if showcase_procs_live; then echo "busy — another session is recording" >&2; exit 1; fi
    # Grab the mutex atomically. mkdir fails if it exists = someone beat us.
    if mkdir "$LOCK" 2>/dev/null; then
      printf '%s|%s|%s|%s' "$$" "$ticket" "$(cat "$QUEUE/$ticket" 2>/dev/null)" "$(date +%s)" > "$META"
      rm -f "$QUEUE/$ticket"
      echo "acquired"; exit 0
    fi
    echo "waiting — lock held" >&2; exit 1 ;;

  release)
    ticket="${2:-}"
    holder="$(cat "$META" 2>/dev/null || true)"
    # Only the owner releases (pid or ticket match) — never yank someone else's lock.
    if [ -z "$holder" ] || [ "${holder%%|*}" = "$$" ] || { [ -n "$ticket" ] && [ "$(printf '%s' "$holder" | cut -d'|' -f2)" = "$ticket" ]; }; then
      rm -rf "$LOCK"; echo "released"
    else
      echo "not owner; refusing to release" >&2; exit 1
    fi ;;

  dequeue) rm -f "$QUEUE/${2:?ticket required}" 2>/dev/null; echo "dequeued" ;;

  next) ft="$(front_ticket)"; [ -n "$ft" ] && echo "$ft ($(cat "$QUEUE/$ft" 2>/dev/null))" || echo "queue empty" ;;

  status)
    reclaim_if_stale
    echo "=== showcase lock ==="
    if [ -d "$LOCK" ]; then
      holder="$(cat "$META" 2>/dev/null || echo '?')"
      pid="${holder%%|*}"
      echo "HELD by pid $pid$(pid_alive "$pid" && echo ' (alive)' || echo ' (DEAD)')  label=$(printf '%s' "$holder" | cut -d'|' -f3)"
    else
      echo "FREE"
    fi
    echo "foreign recording live: $(showcase_procs_live && echo YES || echo no)"
    echo "=== queue (FIFO) ==="
    if [ -n "$(ls "$QUEUE" 2>/dev/null)" ]; then
      i=1; for t in $(ls "$QUEUE" | sort); do echo "  $i. $t ($(cat "$QUEUE/$t" 2>/dev/null))"; i=$((i+1)); done
    else echo "  (empty)"; fi ;;

  *) echo "usage: $0 {enqueue <label>|try-acquire <ticket>|release [ticket]|dequeue <ticket>|next|status}" >&2; exit 2 ;;
esac
