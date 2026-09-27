#!/bin/bash
# Claude Code pipes session JSON on stdin. Icons are Nerd Font (Material Design) glyphs.
# Left: usage (context, 5h limit, weekly limit when >=95%). Right: branch, model, last sent.
export LC_ALL=en_US.UTF-8
input=$(cat)

BRAIN=$'\xf3\xb0\xa7\x91'; GAUGE=$'\xf3\xb0\x8a\x9a'; SAND=$'\xf3\xb0\x94\x9f'; CAL=$'\xf3\xb0\x83\xad'; HIST=$'\xf3\xb0\x8b\x9a'; BRANCH=$'\xf3\xb0\x98\xac'; TREE=$'\xf3\xb0\x99\x85'
SEP=" │ "

eval "$(echo "$input" | jq -r '
  @sh "sid=\(.session_id // "x")",
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "wt=\(.workspace.git_worktree // "")",
  @sh "model=\(.model.display_name // "")",
  @sh "effort=\(.effort.level // "")",
  @sh "ctx=\(.context_window.used_percentage // "")",
  @sh "h5=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "h5r=\(.rate_limits.five_hour.resets_at // "")",
  @sh "d7=\(.rate_limits.seven_day.used_percentage // "")",
  @sh "d7r=\(.rate_limits.seven_day.resets_at // "")"')"

now=$(date +%s)
pct() { printf '%.0f' "$1"; }
join() { local out="" p; for p in "$@"; do [ -z "$p" ] && continue; out="${out:+$out$SEP}$p"; done; printf '%s' "$out"; }

left=(); right=()

[ -n "$ctx" ] && left+=("$BRAIN $(pct "$ctx")%")

if [ -n "$h5" ]; then
  s="$GAUGE $(pct "$h5")%"
  if [ -n "$h5r" ]; then
    m=$(( (h5r - now) / 60 )); [ "$m" -lt 0 ] && m=0
    s="$s $SAND $((m/60))h$(printf '%02d' $((m%60)))m"
  fi
  left+=("$s")
fi

if [ -n "$d7" ] && [ "$(pct "$d7")" -ge 95 ]; then
  s="$CAL wk $(pct "$d7")%"
  if [ -n "$d7r" ]; then
    m=$(( (d7r - now) / 60 )); [ "$m" -lt 0 ] && m=0
    if [ "$m" -ge 1440 ]; then s="$s $SAND $((m/1440))d$((m%1440/60))h"; else s="$s $SAND $((m/60))h$(printf '%02d' $((m%60)))m"; fi
  fi
  left+=("$s")
fi

if [ -n "$cwd" ]; then
  br=$(git -C "$cwd" branch --show-current 2>/dev/null)
  [ -n "$br" ] && right+=("$BRANCH $br")
fi
# worktree dirs usually embed the branch name ("/" -> "-"); skip when redundant
if [ -n "$wt" ] && [ -n "$br" ] && [[ "$wt" == *"${br//\//-}"* ]]; then wt=""; fi
if [ -n "$wt" ]; then
  [ "${#wt}" -gt 24 ] && wt="${wt:0:23}…"
  right+=("$TREE $wt")
fi
model="${model%% (*}"
[ -n "$model" ] && right+=("${model}${effort:+ · $effort}")
[ -f ~/.claude/cache/last-sent-"$sid" ] && right+=("$HIST $(cat ~/.claude/cache/last-sent-"$sid")")

L=$(join "${left[@]}"); Rt=$(join "${right[@]}")

cols=$({ stty size </dev/tty; } 2>/dev/null | awk '{print $2}')
[ -z "$cols" ] && cols=${COLUMNS:-0}

pad=$(( cols - 4 - ${#L} - ${#Rt} ))
if [ "$cols" -gt 0 ] && [ "$pad" -gt 2 ]; then
  printf '%s%*s%s\n' "$L" "$pad" "" "$Rt"
else
  join "$L" "$Rt"; echo
fi
