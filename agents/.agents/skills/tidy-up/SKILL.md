---
name: tidy-up
description: Tidy the comments on a branch's own changes — delete redundant ones, refactor so the code self-documents, keep only short WHY comments — then verify and commit through the hooks. Triggers on "tidy comments", "tidy up the branch", "remove redundant comments and commit", "make the code explain itself". Rebasing is a separate step — use git-rebase-sync for that.
metadata:
  short-description: Tidy comments + self-document + verify + commit
---

# tidy-up

Tidy the comments on the **current branch's own changes**: delete redundant ones, refactor the code so it explains itself, keep only short necessary WHY comments — then verify and **commit through the hooks**.

This skill does **not** rebase. If the branch needs syncing onto its base first, run `git-rebase-sync` (or `git-ship`), then come back and tidy.

## Hard rules

- Operate on the **current** branch. Never switch or create a different branch unless asked.
- Scope every edit to what this branch touched — never reword or delete pre-existing comments outside the diff.
- **Never** use `git commit --no-verify` to dodge a failing hook. If a pre-commit gate (lint-staged, knip, type-check) fails:
  - If it's caused by **this branch's** changes, fix it.
  - If it's a **pre-existing, unrelated** failure, stop and tell the user; let them decide. Only bypass on explicit instruction.
- Conventional-commit messages. No `Co-Authored-By: Claude` trailer.
- Don't invent comments. The goal is *fewer* comments, not reworded ones.

## Step 1 — Scope the change

Find what this branch touched relative to its base (default `origin/develop`):

```bash
git diff --stat origin/{base}..HEAD
```

For each changed file, review only the comments **added/changed in this branch**.

## Step 2 — Tidy

Apply in order of preference:

1. **Delete** comments that restate the code (WHAT-comments), block-header banners, and commented-out code.
2. **Refactor so the code self-documents** instead of commenting:
   - Extract a well-named function/const (e.g. an inline `beforeEach` body → `grantSchemaEditPermission()`; a magic key string → a named `remountKey`).
   - Rename vague identifiers to intent-revealing names.
   - Replace a comment explaining a condition with a named boolean.
3. **Keep** only genuinely non-obvious **WHY** comments (a gotcha, a workaround, a constraint the reader can't infer). One short line where possible.

Heuristic: if a comment could be removed by renaming or extracting something, do that instead of keeping the comment.

## Step 3 — Verify

- `npx eslint --fix <changed files>` then re-lint clean; `npx prettier --check` (or `--write`).
- Type-check (`npx tsc -p tsconfig.json --noEmit`) — confirm no new errors in the changed files.
- Run the tests covering the change (unit / Playwright component / e2e as applicable). For Storybook component tests, ensure Storybook is serving on the expected port first.

## Step 4 — Commit through the hooks

- If the change is already committed and you're only tidying, `git add <files> && git commit --amend --no-edit` re-runs the pre-commit hooks and folds the tidy into that commit. (Amend only touches the top commit — if the tidy spans several commits, commit normally instead, or interactively fold per commit.)
- Otherwise commit normally with a conventional message.
- Let lint-staged + knip + type-check run. Honor the no-`--no-verify` rule above.
- Report the final commit hash.
