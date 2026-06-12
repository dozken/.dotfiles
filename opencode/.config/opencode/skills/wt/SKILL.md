---
name: wt
description: create and prune git worktrees for issue branches. Use when user says new worktree, spin up worktree, make a branch for issue, clean worktrees, prune merged worktrees, or list worktrees. Front and back of the ip flow.
---

# Worktrees (wt)

Lifecycle for issue worktrees that `ip` later dispatches into. Pairs with `ip`.

## Layout (this machine)

- Main checkout: `~/work/<repo>` (e.g. `~/work/vantage-frontend`).
- Worktree dirs: `~/work/<repo>.<branch>` (sibling, dotted suffix).
- Branch names: `feature-<issue>-<slug>`, `bugfix-<issue>-<slug>`.
- Base: `origin/develop`.

Always run `git worktree` from the main checkout. Detect `<repo>` from cwd or default to `vantage-frontend`.

## Create — issue → worktree

1. `git -C ~/work/<repo> fetch origin`.
2. Resolve branch name. From issue: `gh issue view <n> --json title` → slugify title → `feature-<n>-<slug>` (or `bugfix-` if labeled bug). Confirm name if ambiguous.
3. Create off fresh base:
   ```
   git -C ~/work/<repo> worktree add ~/work/<repo>.<branch> -b <branch> origin/develop
   ```
   - If branch already exists on origin, omit `-b` and track it instead.
4. Report the new path. Hand off to `ip <branch>` for dispatch if user wants investigation started.

## Prune — clean merged / stale

1. `git -C ~/work/<repo> worktree list` and `git -C ~/work/<repo> fetch --prune origin`.
2. For each `<repo>.<branch>` worktree, classify:
   - **Merged**: branch merged into `origin/develop` (`git branch --merged origin/develop` contains it, or PR state MERGED via `gh pr view <branch> --json state`). → safe to remove.
   - **Dirty**: uncommitted changes (`git -C <path> status --porcelain` non-empty). → skip, list it.
   - **Stale/unmerged**: not merged, clean, old. → list, remove only with user OK.
3. Remove safe ones:
   ```
   git -C ~/work/<repo> worktree remove ~/work/<repo>.<branch>
   git -C ~/work/<repo> branch -d <branch>
   ```
4. `git -C ~/work/<repo> worktree prune` to clear stale admin entries.

## Rules

- Never `worktree remove --force` a dirty tree without explicit user OK — quote what's uncommitted first.
- Never delete the main `~/work/<repo>` checkout.
- Report: created path, or removed list + skipped (dirty/unmerged) with reasons.
