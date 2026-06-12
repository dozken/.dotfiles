---
name: clean-comments
description: Use when asked to clean a branch's comments — strip issue numbers, drop redundant comments, and rewrite the rest as short caveman-style comments, then commit through the hooks. Triggers on "clean branch", "no issue number in comments", "no redundant comments", "caveman comments", "make comments short and concise".
metadata:
  short-description: Strip issue numbers + redundant comments, caveman-ify, commit
---

# clean-comments

Recurring request. The user wants the comments on the current branch's own changes tidied to four rules, then committed:

1. **Clean the branch** — scope to what this branch touched, not the whole repo.
2. **No issue numbers in comments** — strip `#1234`, `JIRA-123`, `(#3066)`, ticket refs from comments (and from test `describe`/`test`/`it` titles).
3. **No redundant comments** — delete comments that restate the code.
4. **Caveman comments** — whatever survives must be short and concise: caveman style.

## Hard rules

- Operate on the **current** branch only. Never switch or create another branch unless asked.
- Touch only comments **added/changed by this branch** (`git diff origin/{base}..HEAD`). Leave pre-existing comments alone unless asked.
- Don't invent comments. Goal is *fewer and shorter*, never reworded-but-same-length.
- Keep the **commit subject's** issue ref (e.g. `fix(x): … (#3066)`) — that links the PR. The "no issue number" rule is about **comments**, not the commit message.
- No `git commit --no-verify`. If a hook (lint-staged, knip, type-check) fails because of this branch, fix it; if it's a pre-existing unrelated failure, stop and tell the user.
- No `Co-Authored-By: Claude` trailer.

## Step 1 — Scope

```bash
git fetch origin 2>/dev/null
git diff --stat origin/{base}..HEAD   # base default: develop; fall back to HEAD~1 if no upstream
```
Read each changed file. List the comments this branch added/changed.

## Step 2 — Apply the four rules, in order

For each branch-added/changed comment:

1. **Strip issue numbers.** Remove `#NNNN`, `(#NNNN)`, `TICKET-123` from comments and from test titles (`describe("X (#3066)")` → `describe("X")`). The behavior under test is the same; the ticket belongs in the PR, not the test name.
2. **Delete if redundant.** Remove WHAT-comments that restate the code, block-header banners, commented-out code, and JSDoc that only repeats the signature. Prefer a rename/extract over a comment when the code can self-document.
3. **Caveman-ify the survivors.** A comment survives only if it carries non-obvious WHY (gotcha, workaround, constraint, a no-op term, a "reads once on mount"). Rewrite it caveman:
   - Drop articles (a/an/the) and filler (just/really/basically/simply/actually).
   - Fragments OK. One line where possible. Short synonyms.
   - Keep technical terms, identifiers, and symbols exact.
   - Pattern: `[thing] [why]` — e.g.
     - ❌ `// The store reads props only on first mount, so remount when args change.`
     - ✅ `// Store reads props once on mount; remount on arg change.`
     - ❌ `// Gate is datasource/access only. The editable prop is always true today, so passing true keeps the helper's term a no-op.`
     - ✅ `// editable always true here, so pass true (term is a no-op).`
   - Collapse multi-line JSDoc banners into a 1–2 line `//` comment when a comment is still warranted.

Heuristic: if a comment could be killed by renaming or extracting something, do that instead of shortening it.

## Step 3 — Verify

Lint/format/type-check the changed files only (cheap, scoped):
```bash
FILES=$(git diff --name-only --diff-filter=d origin/{base}..HEAD | grep -E '\.(js|jsx|ts|tsx)$')
npx prettier --write $FILES
npx eslint --quiet $FILES
npx tsc --noEmit            # or the project's type-check script
```
Run the tests covering the change if comment edits touched test files (titles renamed → confirm specs still resolve their story/IDs).

## Step 4 — Commit through the hooks

- If the branch's change is already committed and you're only tidying comments: `git add <files> && git commit --amend --no-edit` — re-runs hooks, folds the tidy into the existing commit. If the branch was already pushed, `git push --force-with-lease`.
- Otherwise commit normally with a conventional message.
- Let lint-staged + knip + type-check run. Honor the no-`--no-verify` rule.
- Report the final commit hash and that hooks passed.

## Relation to other skills

- This is the **comment-only** flow. If the user also wants a rebase onto the base first, use `rebase-and-tidy` (it covers rebase + self-documenting refactor). `clean-comments` is the narrower, repeat request: strip issue numbers + redundant comments + caveman-ify + commit.
