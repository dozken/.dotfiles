---
name: verify-issue
description: Use when asked to verify open issues against the current code — fetch oldest open issues from Presight-AI/vantage-frontend, fully investigate whether each is resolved or not, then record the verdict and evidence to the LOCAL ledger only. Never comments, labels, closes, or otherwise writes to GitHub. Designed to run one issue at a time so it can be put in a /loop. Triggers on "verify issues", "check if issues are resolved", "go through the issues and verify", "triage open issues".
metadata:
  short-description: Investigate oldest open issues, record verdict + evidence to the local ledger — read-only against GitHub
---

# verify-issue

Repo: `Presight-AI/vantage-frontend`. Goal: take the **oldest open issues**, prove for each whether it is **resolved** against the current `develop` code, then **record the verdict locally**. Built to process **one issue per invocation** so it can be wrapped in `/loop`.

**READ-ONLY against GitHub. This skill NEVER writes to GitHub — no comments, no `close`, no labels, no `label create`, no field/project edits, no MCP writes.** Every output is a local change: the verdict ledger (below) and, optionally, a regression-test branch. If a verdict seems to warrant a GitHub action, surface it to the user and let *them* decide — do not do it here.

Use the `gh` CLI only for GitHub **reads** (`gh issue list`, `gh issue view`, `gh pr list`, `gh api graphql` queries). Never `gh issue comment` / `gh issue close` / `gh issue edit` / `gh label create` from this skill.

## The local ledger (single source of truth)

Verdicts live in the ledger dir, a sibling of the repo so `git clean` can't nuke it:

```
~/work/vantage-bug-verification/issue-<N>.md
```

One file per issue. Update the existing file if present (don't duplicate); create it if not. Record: verdict, confidence, surface (file:line), the ask, findings, fix-effort, what "resolved" would require, and test coverage. Never write file paths / line numbers into GitHub — they rot; the ledger is where they belong.

## Args

- No arg → process the single **oldest** open issue not yet verified this session.
- A number `N` (e.g. `verify-issue 3`) → process the oldest `N` open issues, one at a time, in order.
- Explicit issue numbers (e.g. `verify-issue 5505 5573`) → process exactly those.
- A type filter (e.g. `verify-issue type:Bug`) → restrict to that native issue type, oldest first.

## Verdict (recorded to the ledger, never to GitHub)

| Verdict | Evidence required | Ledger action |
|---|---|---|
| **RESOLVED** | A specific commit SHA **and/or** PR that demonstrably addresses the reported behavior, ideally confirmed by a live repro | Record RESOLVED + the resolving commit/PR + why it ties to the behavior |
| **PARTIAL** | Some of the reported scope fixed, some still reproducing | Record PARTIAL + what's fixed vs what remains + fix-effort for the remainder |
| **NOT_RESOLVED** | You located the code path / surface and the reported behavior is still present | Record NOT_RESOLVED + surface (file:line) + mechanism + fix-effort + repro |
| **UNSURE** | Can't locate surface, or can't confirm/disprove with confidence | Record UNSURE + what's blocking; surface to the user |

**A merged PR ≠ the bug is gone.** Prefer a live repro over a code-only read — most false RESOLVED verdicts came from "code looks fixed" without reproducing. UNSURE is a legitimate, common outcome; don't force a RESOLVED to look decisive.

## Fix-effort estimate (for every NOT_RESOLVED / PARTIAL verdict)

After confirming a bug is still live, estimate how big the fix is so quick wins can be triaged first. Name the effort with its **full phrase** (never a single letter) and give a one-line reason:

| Effort phrase | Meaning | Typical shape |
|---|---|---|
| **Quick FE-only fix** | trivial, ~1 file, FE-only, mechanism already pinned | pass an existing arg through, delete dead state, add a missing option/guard, CSS/logical-prop fix, wire an existing handler |
| **A few FE files** | a small new component or store change, no backend | new picker + add-path, refetch-on-event wiring, a computed/gate rework across 2–3 files |
| **Multi-module / new surface** | cross-cutting FE work spanning several modules | new widget + data plumbing, tree/store re-architecture, new configurable UI |
| **Needs backend / design decision** | not a self-contained FE win | requires a BE endpoint/broadcast, a schema/contract change, or an unresolved product/design question |

Rules of thumb: if the mechanism is pinned to a single call site and the fix is "change/add these ~10 lines" → **Quick FE-only fix**. If it says "needs backend" / "needs a new WS topic" / "design decision" anywhere → **Needs backend / design decision** (flag it, don't sink time). Note the effort — the full phrase — in the ledger and the loop report line so small ones stand out.

## Step 1 — Pick the issue(s)

Oldest open issues first:
```bash
gh issue list --repo Presight-AI/vantage-frontend --state open \
  --search 'sort:created-asc' \
  --limit 30 --json number,title,createdAt,url
```
Add a `type:` filter when the args ask for one (e.g. `--search 'type:Bug sort:created-asc'`). The `--search` result is already sorted ascending — the first row is the true oldest open issue. Take per the Args rule; skip any already handled this session, and skip **fosemberg-authored** issues (his tickets need his own verdict — never process them here).

## Step 2 — Understand the issue (read EVERY comment AND related issues)

```bash
gh issue view <N> --repo Presight-AI/vantage-frontend --comments
```
Read the body **and every comment, start to finish** — never just the title/body. Comments routinely change the verdict:
- A maintainer may say it's **already done / merged / reverted to backlog / moved to backend** (e.g. "check this in the searchService refactor", "the fix caused other issues, reverting").
- A comment may **narrow or correct** the repro / scope (e.g. "only happens with numeric color fields", "string fields work").
- A comment may carry the **root-cause** the reporter or dev already found, or a **dev/live env URL** to verify against.
- A **recent** comment (check timestamps) may confirm the issue is still live *today* — quote it.

**Rebuttal check (hard gate).** If a comment posted **after** a previous "closing as fixed" / resolution comment disputes it — "still reproducing", "not fixed", "not sure this is fixed", a screenshot/video attached as counter-evidence, "reviewing before merging", "waiting for BA/confirmation", backend-pending, or an unchecked checklist — the issue is **NOT resolved**, regardless of what the code shows. Trust the latest human signal over your own code reading.

**Read related / linked issues too.** A verdict often lives in a sibling, not this issue. Pull them and read their state + comments:
```bash
# tracked sub-issues, duplicates, cross-references, and timeline events (transfers, "duplicate of", "tracked by")
gh issue view <N> --repo Presight-AI/vantage-frontend --json title,body,closedByPullRequestsReferences
gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){issue(number:$n){
  trackedIssues(first:50){nodes{number title state}}
  trackedInIssues(first:20){nodes{number title state}}
  timelineItems(first:100,itemTypes:[CROSS_REFERENCED_EVENT,CONNECTED_EVENT,MARKED_AS_DUPLICATE_EVENT,TRANSFERRED_EVENT]){nodes{__typename}}
}}}' -f o=Presight-AI -f r=vantage-frontend -F n=<N>
```
- **Umbrella / story / tracking issue** (sub-issues, phased P0–Pn, design-doc pointer): treat as resolved **only if every sub-issue is closed**. If any child is open, it's not done.
- **Transferred / moved to backend**: if the actionable scope left this repo, it's OBSOLETE here — flag wrong-repo in the ledger.
- **Duplicate**: inherit the canonical issue's verdict; note the canonical number.
- A linked/related issue may carry the **real fix PR**, or a reopen that invalidates the fix.
- If the issue's **project status is DONE**, treat it as resolved (team status wins) — record that the ledger verdict is superseded by board status, and don't re-flag it.

Extract: the **surface** (component/module — map to CLAUDE.md Component list: Graph, Profiler, Pipelines, Data Catalog, MAP, etc.), exact **repro / acceptance** (as refined by comments), **expected vs actual**, and any **status signal** from comments. If the body or any comment links screenshots, read them (download via `gh` or the asset URL) — UI issues often only make sense visually. In the ledger, note the most relevant comment(s) and their date when they bear on the verdict.

## Step 3 — Investigate in code (full inspection)

1. Locate the responsible code (Grep/Glob/Explore agent, or CodeGraph for the surface). Don't stop at the first file — trace the data/render path. **Verify the surface from the repro** — a wrong surface line produces false verdicts; if you can't pin the surface, the verdict is UNSURE, not NOT_RESOLVED.
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
4. **Reproduce / verify to be sure** — a merged PR is not proof. Boot the app/Storybook (see `run`/`verify` skills) or run the relevant test. For UI/interaction issues prefer a live Storybook story or a Playwright check over code-reading alone. Dead i18n keys / unreachable code paths are a tell the fix never shipped.

## Step 4 — Record the verdict to the ledger (LOCAL ONLY)

Write / update `~/work/vantage-bug-verification/issue-<N>.md`. No GitHub write of any kind.

```markdown
# Issue #<N> — <title>

- **Opened:** <date> · **Type:** <type> · **Surface:** <file:line — component>
- **Verdict:** <RESOLVED | PARTIAL | NOT_RESOLVED | UNSURE> · **Confidence:** <low|medium|high>
- **Fix effort:** <Quick FE-only fix | A few FE files | Multi-module / new surface | Needs backend / design decision> — <one-line reason>   (omit for RESOLVED)
- **Verified:** <today> vs `develop@<sha>` (local-only, no GitHub write)

## Ask
<what the reporter wants, as refined by comments>

## Findings
<the code path, git history, PRs, and live-repro result that back the verdict — cite file:line>

## What "resolved" would require
<for NOT_RESOLVED/PARTIAL: the concrete change; for RESOLVED: the commit/PR that did it>

## Test coverage
<existing tests for this behavior, or "none found">
```

Then print a one-line verdict to the user: `#<N> → <VERDICT> (<confidence>)[ · effort: <full phrase>] — <one-line why>`. If **UNSURE**, say what's blocking and ask the user whether to dig further. If a verdict looks like it should drive a GitHub action (close, label, comment), **surface it and let the user act** — this skill does not.

## Step 5 — Regression test for resolved issues (optional, when missing)

If **RESOLVED** but the surface has **no test covering this behavior**, you may add the smallest test that would have caught it (unit/component/Storybook+Playwright per [TESTING.md](../../TESTING.md) and [src/CLAUDE.md](../../src/CLAUDE.md) — respect the no-store-unit-test and no-RTL-for-perm-gates conventions). This is a **local** code change on a branch: run scoped `type-check`/`eslint`/`prettier`/`test:unit`, tell the user. Don't push without being asked. (Still no GitHub issue write.)

## Loop usage

```
/loop verify-issue            # self-paced: one oldest issue per turn until none left
```
Each turn: handle exactly one issue end-to-end (Steps 1–4, optionally 5), record to the ledger, print the verdict line (`#<N> → <VERDICT> (<confidence>)[ · effort: <full phrase>]`), stop. Include the effort phrase whenever the verdict is NOT_RESOLVED/PARTIAL, so a scan of the loop output surfaces the quick wins. The loop re-invokes for the next-oldest. Stop the loop when `gh issue list` (Step 1) returns no unhandled issues.

## Hard rules

- **Never write to GitHub.** No `gh issue comment` / `close` / `edit` / label ops / `label create`, no MCP comments, no project-field edits. `gh` is for **reads** only. Every artifact of this skill is local (ledger + optional test branch).
- **Read every comment AND related/linked issues before any verdict** (Step 2). A later comment rebutting an earlier close, or an open sub-issue, overrides a code-only "looks fixed" — trust the latest human signal. Project status DONE also wins.
- **A merged PR ≠ resolved.** Prefer a live repro; UNSURE is fine when you can't confirm.
- Skip **fosemberg-authored** issues entirely.
- Findings describe the **mechanism**, never which PR/commit "broke" it (CLAUDE.md: no blame).
- One issue per invocation in loop mode — keeps each turn auditable and interruptible.
- Don't push code changes (regression tests) without explicit user ask.
