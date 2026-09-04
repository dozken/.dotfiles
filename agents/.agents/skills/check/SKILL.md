---
name: check
description: Spin up an isolated worktree for a GitHub issue and start verifying it in a fresh Claude session. Use when the user says "/check {issue_number}", "check issue N", or wants to investigate an issue in its own worktree/window. Creates a wt worktree off fresh develop, opens a new tmux window in it, and launches Claude running the /verify-issue flow for that issue.
metadata:
  short-description: One command — worktree + new tmux window + Claude running /verify-issue for an issue
---

# check

`/check {issue_number}` bootstraps a full investigation environment for one GitHub issue and hands it off to a fresh Claude session.

Repo: `Presight-AI/vantage-frontend`. Main checkout: `/Users/dosmukhamed.zhanibek/work/vantage-frontend`. Worktrees are siblings: `/Users/dosmukhamed.zhanibek/work/vantage-frontend.<branch>`.

Tools used: `gh` (issue metadata), `wt` (worktree create/switch), `tmux` (new window), `claude` (the new session). You are already inside tmux inside WezTerm — "new window" means a **new tmux window**.

## Args

- `{issue_number}` (required) — the GitHub issue to check, e.g. `/check 5575`.

## Flow

Run these from the main checkout. Use absolute paths (tmux `-c` and `wt` need real dirs, not `~`).

### 1. Resolve the issue and branch name

```bash
REPO=Presight-AI/vantage-frontend
MAIN=/Users/dosmukhamed.zhanibek/work/vantage-frontend
N={issue_number}

gh issue view "$N" --repo "$REPO" --json number,title,labels,state,url
```

- If the issue does **not exist** → stop, tell the user.
- If `state` is `CLOSED` → warn the user it's already closed and ask whether to continue before doing anything else.
- Branch prefix: `bugfix-` if any label name is `bug`, otherwise `feature-`.
- Slug: lowercase the title, replace any run of non-alphanumerics with `-`, trim leading/trailing `-`, keep the first ~6 words / ~50 chars.
- Branch: `<prefix>-<N>-<slug>` (e.g. `bugfix-5575-opened-profiles-do-not-persist`).

### 2. Fresh base

```bash
git -C "$MAIN" fetch origin
```

So the new branch is cut from the latest `origin/develop` (the configured base).

### 3. Decide create vs. reuse

```bash
wt list
```

- If a worktree/branch for this issue already exists (matching `vantage-frontend.<branch>` path, or any branch containing `-<N>-`), **reuse** it: drop `--create` in the next step and switch to the existing branch.
- Otherwise create new.

### 4. Open a new tmux window that creates the worktree and launches Claude

New branch:

```bash
tmux new-window -c "$MAIN" -n "check-$N" \
  "wt switch --create <branch> -x claude -- '/verify-issue $N'"
tmux set-window-option -t "check-$N" remain-on-exit on
```

Existing branch (reuse): omit `--create`:

```bash
tmux new-window -c "$MAIN" -n "check-$N" \
  "wt switch <branch> -x claude -- '/verify-issue $N'"
tmux set-window-option -t "check-$N" remain-on-exit on
```

`wt switch --create <branch>` makes the worktree off `origin/develop`, `-x claude` replaces the process with Claude after switching into it, and `-- '/verify-issue $N'` starts that Claude already running the verify-issue flow for the issue.

### 5. Report back

Tell the user, in one or two lines:
- worktree path (`/Users/dosmukhamed.zhanibek/work/vantage-frontend.<branch>`),
- the tmux window name (`check-$N`) and how to reach it (`prefix` + window number, or `prefix w` to pick),
- that a Claude session is now running `/verify-issue $N` there.

Do not switch the current session's window — leave the user where they are.

## Rules

- Never touch the main `vantage-frontend` checkout's branch or working tree.
- Never `wt remove`/`--force` anything here — this skill only creates/opens.
- `gh` for GitHub reads only; this skill never comments or closes. The launched Claude session (`/verify-issue`) owns any GitHub writes, under its own confidence gate.
- One window per issue — if `check-$N` already exists, switch focus to it instead of spawning a duplicate.
