---
name: pr-open
description: open a PR with a body generated from commits and diff, set labels reviewers draft, link issue. Use when user says open pr, create pr, raise pr, make a pull request, or after git-ship when no PR exists yet.
---

# PR Open

Generate a real PR from the branch's commits + diff. Slots after git-ship.

## Pre-flight

1. `git status --short` — ensure clean / pushed. If unpushed, push first (`git push -u origin HEAD`).
2. `git log origin/develop..HEAD --oneline` — the commits this PR introduces.
3. `git diff origin/develop...HEAD --stat` — scope.
4. Check none already exists: `gh pr view` (skip create if it does — update instead).

## Build the PR

- **Base**: `develop` unless user names another.
- **Title**: repo-style conventional, derived from the commits (single theme, ≤ ~70 chars).
- **Body** from the diff, not guesses:
  - `## What` — 2-4 bullets of actual changes.
  - `## Why` — link the issue: `Closes #<n>` (infer from branch name `*/<num>-*` or ask).
  - `## Notes` — migrations, risk, test gaps — only if real.
- Keep it tight. No filler sections.

## Create

```
gh pr create --base develop --title "<title>" --body "<body>"
```

- Draft if WIP: add `--draft`.
- Labels/reviewers if the repo uses them: `--label <l>` / `--reviewer <login>` (check `gh pr create --help` / repo conventions; ask once if unknown, don't invent).
- After create: `gh pr checks --watch`.

## Output

- PR url + number
- title, base, linked issue
- draft or ready, reviewers/labels set
- initial CI state
