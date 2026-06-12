---
name: rebase-and-tidy
description: Use when asked to rebase a branch onto origin/develop (or another base) and then commit while removing redundant comments and refactoring so the code is self-documenting. Triggers on requests like "rebase origin/develop, commit, remove redundant comments", "tidy comments and commit", "make the code explain itself".
metadata:
  short-description: Rebase + comment tidy + commit
---

# rebase-and-tidy

Use this skill when the user wants the recurring two-part flow:

1. **Rebase** the current branch onto the latest `origin/{base}` (default `develop`).
2. **Tidy comments** on the branch's own changes — delete redundant ones, refactor the code so it explains itself, keep only short necessary WHY comments — then **commit through the hooks**.

## Hard rules

- Operate on the **current** branch. Never switch or create a different feature branch unless asked.
- Before any history rewrite (`git rebase`, `git push --force*`), create a local backup tag. Don't push backup refs.
- **Never** use `git commit --no-verify` to dodge a failing hook. If a pre-commit gate (lint-staged, knip, type-check) fails:
  - If it's caused by **this branch's** changes, fix it.
  - If it's a **pre-existing, unrelated** failure, stop and tell the user; let them decide. Only bypass on explicit instruction.
- Conventional-commit messages. No `Co-Authored-By: Claude` trailer.
- Don't invent comments. The goal is *fewer* comments, not reworded ones.

## Step 1 — Rebase onto the base

If the branch has merge commits or conflicts are likely, defer to the `git-rebase-sync` skill. Otherwise:

```bash
git fetch origin
git status                       # must be clean; stop if a rebase/merge is in progress
git rev-list --count --merges origin/{base}..HEAD   # if > 0, ask: --rebase-merges vs flatten
git tag -a "{branch}-rebase-backup-$(date +%Y%m%d-%H%M%S)" -m "pre-rebase backup" HEAD
git rebase origin/{base}
```

- Resolve conflicts deliberately; if intent is ambiguous, ask one targeted question rather than guessing.
- After rebasing, confirm `git merge-base --is-ancestor origin/{base} HEAD` reports the branch is on top of the latest base.

## Step 2 — Tidy comments on the branch's changes

Scope to what this branch touched: `git diff --stat origin/{base}..HEAD`. For each changed file, review the comments **added/changed in this branch** (not pre-existing ones).

Apply this order of preference:

1. **Delete** comments that restate the code (WHAT-comments), block-header banners, and commented-out code.
2. **Refactor so the code self-documents** instead of commenting:
   - Extract a well-named function/const (e.g. an inline `beforeEach` body → `grantSchemaEditPermission()`; a magic key string → a named `remountKey`).
   - Rename vague identifiers to intent-revealing names.
   - Replace a comment explaining a condition with a named boolean.
3. **Keep** only genuinely non-obvious **WHY** comments (a gotcha, a workaround, a constraint that the reader can't infer). Make each one short and concise — a single line where possible.

Heuristic: if a comment could be removed by renaming or extracting something, do that instead of keeping the comment.

## Step 3 — Verify

- `npx eslint --fix <changed files>` then re-lint clean; `npx prettier --check` (or `--write`).
- Type-check the project (`npx tsc -p tsconfig.json --noEmit`) — confirm no new errors in the changed files.
- Run the tests that cover the change (unit / Playwright component / e2e as applicable). For Storybook component tests, ensure Storybook is serving on the expected port first.

## Step 4 — Commit through the hooks

- If the change is already committed and you're only tidying, `git add <files> && git commit --amend --no-edit` re-runs the pre-commit hooks and folds the tidy in.
- Otherwise commit normally with a conventional message.
- Let lint-staged + knip + type-check run. Honor the no-`--no-verify` rule above.
- Report the final commit hash and that the branch sits on top of the latest base.
