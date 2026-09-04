---
name: deep-review
description: Deep code review that reads beyond the diff. Use when the user says "/deep-review", "deep review this", "review this properly", "review like b091", or wants a review that catches what /code-review max misses. Runs a workflow with a PR-context stage, 18 finder angles, and 3-vote adversarial verification. Two tiers - default and ultra. Finds only - to review AND fix in rounds until clean, use /grill.
allowed-tools: Workflow, Bash, Read, Grep, Glob, ReportFindings
---

# deep-review

A code review harness built to beat the built-in `/code-review max`.

**Invoke it by calling the Workflow tool. Do not review by hand.**

```
Workflow({
  scriptPath: "~/.claude/skills/deep-review/review-workflow.js",
  args: "<tier> [target]"
})
```

The path is absolute on purpose — this skill is global and runs against whatever
repo the session is in. Expand `~` if the tool does not.

- `tier` — `default` or `ultra`. Omit and it defaults to `default`.
- `target` — optional: a PR number, branch, ref range, path, or free-form scope
  instruction (`"only src/case"`, `"focus on the async paths"`). Omit to review
  the current branch.

Parse the user's request into that one string and pass it. Examples:

| User says | args |
|---|---|
| `/deep-review` | `"default"` |
| `/deep-review 6062` | `"default 6062"` |
| `/deep-review ultra` | `"ultra"` |
| `/deep-review ultra 6062` | `"ultra 6062"` |
| `/deep-review only the store files` | `"default only the store files"` |

The workflow runs in the background and returns via task notification. When the
result arrives, report it — see **Reporting** below.

## Portability

The angles were mined from a React/TypeScript/MobX frontend and keep that
codebase's worked examples, because the specificity is what makes them bite. A
Phase-0 stage detects the actual base branch and stack (languages, frameworks,
state container, test runner, locale layout, paired repos) and injects it into
every finder, which is told to map each example onto this repo's equivalent —
and to return nothing when its whole subject is absent (no UI, no i18n, no async)
rather than invent findings or flag the absence of an idiom the repo never
adopted.

The conventions checklist is built FROM whatever CLAUDE.md files govern the
changed files, not from a fixed list.

## Why this exists

`/code-review max` is not deeper than `xhigh`. From its own source:

```js
xhigh: { correctnessAngles: 5, perAngle: 8, maxFindings: 15, sweep: true },
max:   { correctnessAngles: 5, perAngle: 8, maxFindings: 15, sweep: true },
// max -> same structure as xhigh (the API reasoning effort differs, not the fan-out)
```

Its real limit is not effort — it is **scope**. Every one of its finder angles is
told to *"run the diff command above and review ONLY through the lens of your
assigned angle."* Nothing reads the PR body, the CI state, the linked issue, or
what landed on the base branch since the fork.

This skill's angles were reverse-engineered from **193 defect classes mined out
of 50 PRs** of this repo's strongest reviewer. **143 of those 193 (74%) required
reading code outside the diff.** Mapped against max's angles: 4 classes fully
covered, 9 partial, 8 nominal, **76 gaps**.

## What it does differently

| | `/code-review max` | `/deep-review` |
|---|---|---|
| Pre-diff context | none | **Phase 0**: PR body claims, CI, merge-base drift, linked issue |
| Finder angles | 5 correctness + 1 merged cleanup | **18** — A–E, plus F–O, plus altitude, efficiency, cleanup |
| Beyond-diff | structurally no | 8 angles explicitly licensed to leave the diff |
| Altitude / bandaid | 1 of 5 lenses in one shared agent, ranked below all correctness | **its own agent, its own budget, ranked with correctness** |
| Verify | 1 vote, one skeptic can kill a real bug | **3 independent adversarial votes, 2 refutes to kill** |
| Sweep | 1 pass | 1 pass (default) / **loop-until-dry** (ultra) |
| Suppression | generic ("pre-existing" = drop) | calibrated — *pre-existing is not automatic suppression; test whether the diff changes its frequency or reachability* |
| Output | findings only | findings **+ "non-issues I checked and cleared"** |

### The angles

**A–E** (verbatim from max, they are well-tuned): diff scan, removed-behavior,
cross-file tracer, language pitfalls, wrapper/proxy.

**F–M** (mined — these are the ones max cannot run):

- **F · parallel-site hunter** — a fix landed at one site while its twin ships
  unfixed. Highest-yield angle in the corpus. Fingerprint-grep outward from every
  added enum value / extracted helper / patched call site.
- **G · async lifecycle** — post-await writes with no identity guard, latches
  assigned inside `runInAction`, loading flags reset only in a WS callback,
  teardown missing an inverse. max's entire async coverage is the phrase
  *"missing await"*.
- **H · wiring & resolution** — every value produced must reach a reader. Dead
  controls, `?taskId` read by nobody, i18n keys missing from `ar/`. The defect is
  an *absent reader in another file* — there is no wrong line to scan.
- **I · test mutation** — delete the guard; which assertion goes red? Mock return
  values vs production constants. No max angle reads the test tree at all.
- **J · PR context & lockstep** — author claims vs the code, backend lockstep,
  base-branch drift, fixup-commit messages as claims to verify.
- **K · input-domain adversary** — substitute values, don't read for intent.
  `[].some() === false` ⇒ SUCCESS. `?? 0` making `>= 0` a tautology.
- **L · render surface** — walk *up* the JSX ancestor chain into parent files.
  Clipped popovers, collapsed widths, `calc()` at 768px, RTL logical props.
- **M · config, secrets, conventions** — the files every other angle skips, plus
  a positive-control checklist reported by name even when clean.

**N–O** (added for the axes the corpus under-covered — both need a second file
to prove a finding, so both carry the beyond-diff license):

- **N · ownership & dependency direction** — what the change *forces other files
  to know*. Shared infra importing a feature; a render concern (navigate, `t()`,
  close) passed into a store; an enum member registered at 3 of 4 sites; a param
  bag whose callers pass `undefined` for half. Files structure, never taste — a
  candidate with no named second file, missed site, or caller obligation is
  dropped, not softened.
- **O · determinism** — same inputs, different output across two runs, machines,
  locales, timezones, or arrival orders. Clock/random/env reaching rendered or
  persisted state, ties with no tiebreaker, keys built from unordered
  structures, order-sensitive reduces, and unseeded/unpinned tests. Every
  candidate must name the two concrete runs that disagree.

**Efficiency** was promoted out of the merged cleanup agent into its own agent
and budget (it was one of four lenses sharing one cap, so it was the lens that
lost). It requires a named multiplier — per render, per row, per boot; a cost
with no scale is not a finding.

## Reporting

The workflow returns `{ level, summary, findings, cleared, refuted, stats }`.

- `findings` — ranked most-severe first, each with `file`, `line`, `summary`,
  `failure_scenario`, `category`, `verdict`, `tally` (e.g. `2C/1P/0R`), and
  `outsideDiff`.
- `cleared` — non-issues checked and cleared. **Report these.** A reviewer who
  says what they attacked and could not break is more trustworthy than one who
  reports only hits.
- `refuted` — killed by majority vote. Mention the count; list them only if asked.

Report findings with the `ReportFindings` tool if it is available, once, with
`{ level, findings }`, most-severe first — and do not also print them as text.
If it is not available, print them: lead with whether the PR's core value
actually works, then findings ranked, then the cleared list, then a one-line
refuted count.

Flag `outsideDiff: true` findings in the summary rather than as inline comments —
they have no diff line to attach to.

## Cost

This is expensive. Measured, not estimated — `default` on PR #6062 (16 files,
392 additions):

| | agents | tokens | wall-clock |
|---|---|---|---|
| `default` | 135 | 8.5M | ~67 min |

`ultra` raises `perAngle` to 10, 3-votes the cleanup candidates too, and loops
the sweep until two dry rounds — budget for meaningfully more than that.

Most of the cost is Verify: candidates × 3 votes. The pool is deduped before
verification (near-identical claims at one location collapse to one), but a
16-file PR still lands ~40 distinct locations × 3 = ~120 verifier agents.

Use `default` for a real PR you are about to ship or block. Use `/code-review
high` for a quick pass — do not run this on a one-line diff, and do not run
`ultra` without a reason.

## Iterating

The script is a plain workflow script. Edit
`~/.claude/skills/deep-review/review-workflow.js` and re-invoke with the same
`scriptPath`. To resume a run after an edit, pass `resumeFromRunId` — unchanged
`agent()` calls replay from cache.

It runs in a bare sandbox: no imports, no filesystem, no `Date.now()` /
`Math.random()`. Keep it self-contained. Top-level `return` is legal there but
fails `node --check` — wrap in an async function to syntax-check.
