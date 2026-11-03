#!/bin/bash
# Per-pane tmux count of Claude background shells (Bash run_in_background,
# Monitor). Hooks can't see these finish, so poll: called from status-right
# every status-interval, prints nothing, sets/unsets @claude_bg per pane.
# A Claude shell is `zsh -c source ~/.claude/shell-snapshots/...`, child of the
# claude process, which is the pane process or its child.
[ -n "$TMUX" ] || exit 0

counts=$(
  awk 'NR==FNR { pane[$2] = $1; next }
       { ppid[$1] = $2; if ($0 ~ /shell-snapshots\//) shell[$1] = 1 }
       END {
         for (p in shell) {
           a = ppid[p]; b = ppid[a]
           id = (a in pane) ? pane[a] : (b in pane) ? pane[b] : ""
           if (id != "") n[id]++
         }
         for (id in n) print id, n[id]
       }' \
    <(tmux list-panes -a -F '#{pane_id} #{pane_pid}') \
    <(ps -axo pid=,ppid=,command=)
)

tmux list-panes -a -F '#{pane_id} #{@claude_bg}' | while read -r id old; do
  new=$(awk -v id="$id" '$1 == id { print $2 }' <<<"$counts")
  [ "$new" = "$old" ] && continue
  if [ -n "$new" ]; then tmux set-option -p -t "$id" @claude_bg "$new"
  else tmux set-option -pu -t "$id" @claude_bg; fi
done
exit 0
