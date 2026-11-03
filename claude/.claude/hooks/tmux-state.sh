#!/bin/bash
# Per-pane tmux indicator for Claude state (pane options, so several Claude
# panes in one window keep separate state; window tab shows each via #{P:}).
# Usage: tmux-state.sh prompt|working|waiting|stop|substart|substop|clear
#        tmux-state.sh seen <window_id>   (tmux hook: clear ✓ on its panes)
if [ "$1" = seen ]; then
  tmux list-panes -t "$2" -F '#{pane_id} #{@claude}' 2>/dev/null |
    awk '/✓/ { print $1 }' | while read -r id; do tmux set-option -pu -t "$id" @claude; done
  exit 0
fi
[ -n "$TMUX_PANE" ] || exit 0
t=(-t "$TMUX_PANE")
WORK='#[fg=#f9e2af]●'; WAIT='#[fg=#fab387,bold]?'; DONE='#[fg=#a6e3a1]✓'

lock="/tmp/claude-tmux-${TMUX_PANE#%}.lock"
for _ in $(seq 50); do
  mkdir "$lock" 2>/dev/null && { trap 'rmdir "$lock" 2>/dev/null' EXIT; break; }
  sleep 0.02
done

get() { tmux show-option -pqv "${t[@]}" "$1" 2>/dev/null; }
set_() { tmux set-option -p "${t[@]}" "$1" "$2" 2>/dev/null; }
n=$(get @claude_n); n=${n:-0}
idle=$(get @claude_idle)

case "$1" in
  prompt)   set_ @claude_n 0; set_ @claude_idle 0; set_ @claude "$WORK" ;;
  working)  set_ @claude "$WORK" ;;
  waiting)  set_ @claude "$WAIT" ;;
  stop)     set_ @claude_idle 1
            if [ "$n" -gt 0 ]; then set_ @claude "$WORK"; else set_ @claude "$DONE"; fi ;;
  substart) set_ @claude_n $((n+1)); set_ @claude "$WORK" ;;
  substop)  [ "$n" -gt 0 ] && n=$((n-1)); set_ @claude_n "$n"
            if [ "$n" -eq 0 ] && [ "$idle" = 1 ]; then set_ @claude "$DONE"; fi ;;
  *)        for o in @claude @claude_n @claude_idle; do tmux set-option -pu "${t[@]}" "$o" 2>/dev/null; done ;;
esac
exit 0
