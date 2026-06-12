---
name: git-ship
description: commit, rebase origin/develop, push, monitor ci. Use when user says git ship, ship it, sync and push, or asks to commit then rebase onto origin/develop and watch GitHub checks.
---

# Git Ship

Use for repeat flow:
- inspect status, diff, recent commits
- stage only intended repo files
- commit with repo-style conventional message
- fetch origin
- rebase current branch onto `origin/develop`
- resolve conflicts carefully, never touch unrelated user changes
- push with `--force-with-lease` when rebase rewrites history
- monitor GitHub PR checks until terminal state or useful status point

## Rules

- Never stage unrelated files.
- Never revert user changes.
- Before commit, inspect:
  - `git status --short`
  - `git diff -- <intended files>` or `git diff`
  - `git log --oneline -10`
- Use minimal conventional commit message matching repo style.
- Before rebase, create backup tag:
  - `git tag -a <branch>-rebase-backup-$(date +%Y%m%d-%H%M%S) -m "pre-rebase backup" HEAD`
- Rebase onto `origin/develop` unless user names another base.
- Use `git push --force-with-lease origin HEAD` after rebase if needed.
- After push, monitor checks with `gh`.
- Report only intended files committed and latest CI state.

## Default Command Sequence

Run in this order unless user asks otherwise:

1. `git status --short`
2. `git diff -- <intended files>`
3. `git log --oneline -10`
4. `git add <intended files>`
5. `git commit -m "<message>"`
6. `git fetch origin`
7. `git tag -a <branch>-rebase-backup-$(date +%Y%m%d-%H%M%S) -m "pre-rebase backup" HEAD`
8. `git rebase origin/develop`
9. `git push --force-with-lease origin HEAD`
10. `gh pr checks --watch`

## Conflict Policy

- Read conflicted files before editing.
- Keep smallest correct resolution.
- If intent unclear, ask one short question.
- If generated snapshot or lockfile conflict, prefer regeneration over manual merge when practical.

## Output

Return:
- commit hash and message
- whether rebase happened cleanly or with conflicts
- push result
- CI/check status summary
