#!/usr/bin/env bash
# Seed a new worktree's CodeGraph index from the main checkout, so sessions there
# can query it. Does nothing if the main checkout isn't indexed or a tool is missing:
# indexing stays each developer's choice.
#   ~/.claude/scripts/worktree-codegraph.sh <worktree>
set -euo pipefail
wt=${1:?usage: worktree-codegraph.sh <worktree>}
root=$(dirname "$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir)")
src=$root/.codegraph/codegraph.db
[[ -f $src && ! -e $wt/.codegraph/codegraph.db ]] || exit 0
command -v codegraph >/dev/null && command -v sqlite3 >/dev/null || exit 0
mkdir -p "$wt/.codegraph"
cp "$root/.codegraph/.gitignore" "$wt/.codegraph/"
sqlite3 "$src" ".backup '$wt/.codegraph/codegraph.db'"
codegraph sync "$wt" >/dev/null
