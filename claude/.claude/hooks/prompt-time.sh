#!/bin/bash
# Record last prompt send time per session; statusline displays it.
sid=$(jq -r '.session_id // "x"')
mkdir -p ~/.claude/cache
date '+%-I:%M %p' > ~/.claude/cache/last-sent-"$sid"
