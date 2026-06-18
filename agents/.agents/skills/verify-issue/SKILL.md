---
name: verify-issue
description: Use when asked to verify open issues against the current code — fetch oldest open issues from Presight-AI/vantage-frontend, fully investigate whether each is resolved or not, then either comment "still open" + label, or comment the resolving commit/PR and close. Designed to run one issue at a time so it can be put in a /loop. Triggers on "verify issues", "check if issues are resolved", "go through the issues and verify", "triage open issues".
metadata:
  short-description: Investigate oldest open issues, comment verdict, close resolved ones with commit/PR evidence
---

# verify-issue

Repo: `Presight-AI/vantage-frontend`. Goal: take the **oldest open issues**, prove for each whether it is **resolved** against the current `develop` code, then act on the verdict. Built to process **one issue per invocation** so it can be wrapped in `/loop`.

Use the `gh` CLI for ALL GitHub reads/writes. **Never use GitHub MCP tools for comments** (CLAUDE.md ban). `gh issue comment` / `gh issue close` are fine.

## Args

- No arg → process the single **oldest** open issue not yet verified this session.
- A number `N` (e.g. `verify-issue 3`) → process the oldest `N` open issues, one at a time, in order.
- Explicit issue numbers (e.g. `verify-issue 5505 5573`) → process exactly those.
- A type filter (e.g. `verify-issue type:Bug`) → restrict to that native issue type, oldest first.

## Confidence gate (decides the action)

| Verdict | Evidence required | Action |
|---|---|---|
| **Resolved** | A specific commit SHA **and/or** PR that demonstrably addresses the reported behavior | Comment evidence → `close` |
| **Not resolved** | You located the code path / surface and the reported behavior is still present | Comment findings → add label `needs-fix` |
| **Unsure** | Can't locate surface, or can't confirm/disprove resolution with confidence | Report to user only. No GitHub write. Ask before any close. |

**Closing is irreversible-ish and outward-facing.** Only close on the **Resolved** row, and only when you can name the commit/PR. If a loop run hits **Unsure**, stop and surface it — do not guess.

## Step 1 — Pick the issue(s)

Oldest open issues first:
```bash
gh issue list --repo Presight-AI/vantage-frontend --state open \
  --search 'sort:created-asc' \
  --limit 30 --json number,title,createdAt,url
```
Add a `type:` filter when the args ask for one (e.g. `--search 'type:Bug sort:created-asc'`). The `--search` result is already sorted ascending — the first row is the true oldest open issue. Take per the Args rule; skip any already handled this session.

## Step 2 — Understand the issue (read EVERY comment)

```bash
gh issue view <N> --repo Presight-AI/vantage-frontend --comments
```
Read the body **and every comment, start to finish** — never just the title/body. Comments routinely change the verdict:
- A maintainer may say it's **already done / merged / reverted to backlog / moved to backend** (e.g. "check this in the searchService refactor", "the fix caused other issues, reverting").
- A comment may **narrow or correct** the repro / scope (e.g. "only happens with numeric color fields", "string fields work").
- A comment may carry the **root-cause** the reporter or dev already found, or a **dev/live env URL** to verify against.
- A **recent** comment (check timestamps) may confirm the issue is still live *today* — quote it.

Extract: the **surface** (component/module — map to CLAUDE.md Component list: Graph, Profiler, Pipelines, Data Catalog, MAP, etc.), exact **repro / acceptance** (as refined by comments), **expected vs actual**, and any **status signal** from comments. If the body or any comment links screenshots, read them (download via `gh` or the asset URL) — UI issues often only make sense visually. In the report, note the most relevant comment(s) and their date when they bear on the verdict.

## Step 3 — Investigate in code (full inspection)

1. Locate the responsible code (Grep/Glob/Explore agent for the surface). Don't stop at the first file — trace the data/render path.
2. Check git history for the area since the issue was opened:
   ```bash
   ISSUE_DATE=$(gh issue view <N> --repo Presight-AI/vantage-frontend --json createdAt --jq .createdAt)
   git log --since="$ISSUE_DATE" --oneline -- <paths>     # commits touching the surface
   git log --all --oneline --grep "<N>"                    # commits referencing the issue number
   ```
3. Search merged PRs that reference the issue:
   ```bash
   gh pr list --repo Presight-AI/vantage-frontend --state merged --search "<N>" --json number,title,mergedAt,url
   ```
4. **Reproduce / verify to be sure** when code inspection is ambiguous — boot the app/Storybook (see `run`/`verify` skills) or run the relevant test. For UI/interaction issues prefer a Storybook story or a Playwright check over guessing.

## Step 4 — Verdict + action

**Resolved** — comment evidence, then close:
```bash
gh issue comment <N> --repo Presight-AI/vantage-frontend --body "$(cat <<'EOF'
Verified resolved against `develop`.

- **Resolving commit:** <sha> — <subject>
- **PR:** #<pr> (merged <date>)
- **Why it's resolved:** <1–3 lines tying the change to the reported behavior; cite file:line>

Reproduced the original steps; behavior now correct.
EOF
)"
gh issue close <N> --repo Presight-AI/vantage-frontend --reason completed
```

**Not resolved** — comment findings, label:
```bash
gh issue comment <N> --repo Presight-AI/vantage-frontend --body "$(cat <<'EOF'
Still open on `develop`.

- **Where:** <file:line — the code path>
- **Why it still happens:** <mechanism, no blame / no "PR X broke it">
- **Repro:** <steps / story / test that shows it>
EOF
)"
gh issue edit <N> --repo Presight-AI/vantage-frontend --add-label needs-fix
```
> If `needs-fix` doesn't exist, create it once: `gh label create needs-fix --repo Presight-AI/vantage-frontend --color B60205 --description "Confirmed still reproducing"`.

**Unsure** — print verdict + what's blocking to the user. No write. Ask before closing anything.

## Step 5 — Regression test for resolved issues (when missing)

If **Resolved** but the surface has **no test covering this behavior**, add the smallest test that would have caught it (unit/component/Storybook+Playwright per [TESTING.md](../../TESTING.md) and [src/CLAUDE.md](../../src/CLAUDE.md) — respect the no-store-unit-test and no-RTL-for-perm-gates conventions). Mention the added test in the issue comment. This is a code change: make it on a branch, run scoped `type-check`/`eslint`/`prettier`/`test:unit`, and tell the user — don't push without being asked.

## Loop usage

```
/loop verify-issue            # self-paced: one oldest issue per turn until none left
```
Each turn: handle exactly one issue end-to-end (Steps 1–5), report the verdict line, stop. The loop re-invokes for the next-oldest. Stop the loop when `gh issue list` (Step 1) returns no unhandled issues, or on the first **Unsure** that needs a human.

## Hard rules

- `gh` CLI only for GitHub writes; never MCP comments.
- Never close on **Unsure** or **Not resolved**. Close only with a named commit/PR.
- Comments describe the **mechanism**, never which PR/commit "broke" it (CLAUDE.md: no blame).
- One issue per invocation in loop mode — keeps each turn auditable and interruptible.
- Don't push code changes (regression tests) without explicit user ask.
