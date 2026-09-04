---
name: grill
description: Grill a PR or branch until it is clean — review, fix, re-review, in rounds, rebasing onto the moving base each round, until a round finds nothing. Use when the user says "/grill", "grill this PR", "review and fix until it's perfect", "keep reviewing and fixing until it's done", "keep reviewing until clean", "harden this branch before I ship it". Wraps deep-review's 18 angles in a fix loop with regression, no-progress and rebase-conflict guards. Has a hands-off until-clean mode. Never merges, never force-pushes.
metadata:
  short-description: Review → fix → re-review in rounds until a round comes back clean. Gated, capped, auditable.
allowed-tools: Workflow, Bash, Read, Edit, Write, Grep, Glob, Skill
---

# grill

`/deep-review` finds and stops. `/grill` finds, **fixes, and comes back for
more** — until a round returns nothing.

One round = review → apply → gate → commit. The loop is the point: a fix is a
new, unreviewed change, and the round that reviews it is the one that catches
the bug the fix introduced.

## Args

`/grill [target] [ultra] [rounds:N | until-clean]`

- `target` — PR number, branch, ref range, path, or free-form scope. Omit for the current branch.
- `ultra` — raises the tier for **round 1 only** (see Tiers). Expensive; needs a reason.
- `rounds:N` — round cap. Default **3**, max **6**.
- `until-clean` — hands-off: no user round cap, run until it converges or a guard stops it. See below.

Examples: `/grill` · `/grill 6062` · `/grill ultra rounds:5` · `/grill only src/case` · `/grill 6062 until-clean`

## The loop

```
r = 1
loop:
  sync base                                  -> fetch; rebase if base moved (see Base drift)
  findings = review(round r)
  if no CONFIRMED findings and r > 1        -> DONE (clean round)
  if no CONFIRMED findings and r == 1       -> DONE (nothing to fix)
  apply fixes                                -> only what a finding names
  gate                                       -> must be green
  commit                                     -> one commit per round
  if r == cap                                -> STOP, report what is left
  r++
```

### Round 1 — full review

```
Workflow({ scriptPath: "~/.claude/skills/deep-review/review-workflow.js",
           args: "<default|ultra> <target>" })
```

Runs in the background; returns `{ findings, cleared, refuted, stats }` via task
notification. Record `git rev-parse HEAD` as `BASE_SHA` before touching anything.

### Rounds 2+ — delta review, not a re-run

A full re-review every round is ~135 agents each and mostly re-derives what
round 1 already cleared. Round 2+ reviews **what changed and whether the fixes
took**, by passing a free-form scope target:

```
args: "default <original-target> — review the changes since <last-round-sha>, plus verify each
       of these previously-reported findings is actually fixed and the fix introduced nothing:
       <one line per finding fixed last round, with its file and summary>"
```

Two jobs per later round, in this order:

1. **Did the fix land?** A finding reported fixed that reproduces is a
   **no-progress** signal, not a new finding — see Guards.
2. **What did the fix break?** Fixes are unreviewed code. Round 2 exists mostly
   for this.

## Base drift — sync at the top of every round

A grill run is long (hours, in `until-clean`), and the base branch moves under
it. Reviewing against a stale base is the failure deep-review's own context
stage warns about: *green CI on a stale base proves nothing*. So every round
starts with a sync.

```bash
git fetch origin
git rev-list --count HEAD..origin/<base>     # 0 = nothing to do
```

- **Base unchanged** → proceed, no rebase, no noise.
- **Base moved** → `Skill: git-rebase-sync`, then re-run the gate before
  reviewing. New base code plus your fixes is a combination nothing has compiled
  yet.
- **Rebase conflicts** → **stop** (guard). Resolving conflicts is a judgment
  call about someone else's change, not a loop's job. Report which files, leave
  the branch where `git rebase --abort` puts it.

**A rebase invalidates the round anchor.** Delta reviews (rounds 2+) point at
`<last-round-sha>`, and a rebase rewrites those shas so the range is meaningless.
After a rebase, scope the next round by **file list** instead — the files your
last round touched — and re-derive the range from the new merge-base.

**A rebase widens the next round.** If what landed on the base touches the same
files or subsystem as your diff, the next round is not a pure delta: review your
files against the new base, not just your own changes. The whole point of
noticing base drift is that the interaction is new code neither side reviewed.

**Rebase ≠ push.** Grill rebases locally and does not push. A rebased branch
that was already pushed has diverged from its remote and needs
`--force-with-lease` — that is the owner's call at their push step (or
`the-job`'s), never grill's. Say in the report when the branch was rebased so
nobody is surprised by the divergence.

## Applying fixes — where the mess gets made

The loop only converges if each round's diff is **attributable**. Rules, in
force every round:

| Verdict | Action |
|---|---|
| **CONFIRMED** | Fix it. |
| **PLAUSIBLE** | Fix only if the fix is local, cheap and obviously correct. Otherwise **park** with the reason. A speculative fix costs a round and can't be verified. |
| **REFUTED** | Nothing. Do not "fix it anyway to be safe" — that is how scope leaks. |
| **outsideDiff** | Park by default; it is not this PR's job. **Exception**: a parallel site of a finding inside the diff (angle F). Half-fixing a twin is the defect the angle exists to catch — fix both or neither, and say which you chose. |

Hard rules:

- **No drive-by changes.** Every hunk in a round's commit must trace to a named
  finding. Refactors, renames, and "while I'm here" cleanups do not belong in a
  grill round — they add unreviewed surface and reset the loop.
- **Never edit a test to make a finding disappear.** If a finding says a test
  asserts a proxy, fix the assertion to the real symptom — that is a change to
  what the test *proves*, not to whether it passes.
- **Fix at the seam the finding names**, not at the first line that reproduces.
  If the finding is an altitude/angle-N one, the fix is structural; a local
  patch will be re-found next round.
- **Park loudly.** Everything parked goes in the final report with its reason.
  Silence reads as "clean".

After applying, state each fix as a **falsifiable claim** ("the latch is now
assigned before the await, so two callers cannot both enter"). Those claims are
what round N+1 grades — same shape deep-review already uses for PR-body claims.

## Gate (every round, before every commit)

Detect the repo's real gate — its CI config, its CLAUDE.md "before pushing"
section, its package scripts — and run that, scoped to the diff. For this repo:

```bash
BASE=origin/develop
FILES=$(git diff --name-only --diff-filter=d "$BASE"...HEAD | grep -E '\.(js|jsx|tsx|ts)$')
npm run type-check
if [ -n "$FILES" ]; then
  echo "$FILES" | xargs env ESLINT_TYPED=1 npx eslint --quiet
  echo "$FILES" | xargs npx prettier --check
fi
npm run knip
npm run test:unit
```

Red gate → fix it inside the same round. A round never ends red, and a round
never commits over a red gate.

Commit per round via `Skill: caveman-commit`, subject naming the round:
`fix(<scope>): grill round <r> — <k> findings`. No Claude co-author trailer.

## Guards — how it stops

It must terminate loudly, not spin.

- **Clean round** → done. Report the round number.
- **Round cap** (default 3) → stop, report every finding still open. Do not
  silently extend.
- **No progress** — a finding fixed in round r is re-found in round r+1 at the
  same location. The fix did not take, and a third attempt usually won't either.
  **Stop and hand it to the user** with both attempts.
- **Regression** — a round's fixes produce more CONFIRMED findings than they
  closed. Stop. Report it and offer to revert that round's commit
  (`git revert <sha>`, never a force-push, never a reset on a pushed branch).
- **Thrash** — round r re-touches a line round r-1 touched, for a *different*
  finding. Two findings disagree about the same line; a loop cannot arbitrate
  that. Escalate.
- **Rebase conflict** — the base moved into your files and git can't reconcile
  it. Abort the rebase, report the conflicting files, stop.
- **Budget exhausted** (`until-clean`) — not enough left for a full round plus
  its gate. Stop at the last green commit rather than starting a round you
  cannot finish.

On any guard trip: leave the branch in its last green committed state, report,
and stop. Never ship a red or half-applied round.

## `until-clean` — hands-off

Same loop, no user round cap. You walk away; it stops on its own. The guards
below are not a safety net here, they are the **termination condition** — a
capped run can lean on the cap, an uncapped one cannot.

What changes:

- **No `rounds:N`.** Runs until it converges or a guard trips.
- **Hard wall at 10 rounds.** A runaway backstop, not a target. Reaching it
  means the loop never converged — report that plainly; it is a failure, not a
  finish.
- **Diminishing-returns stop.** Two consecutive rounds producing zero CONFIRMED
  findings (only PLAUSIBLE/parked) → done. Chasing PLAUSIBLE with speculative
  fixes is exactly how an uncapped loop spins.
- **Budget stop.** Before starting a round, check remaining budget against what
  a round costs here (round 1's measured cost is the estimate). Not enough for a
  full round → stop cleanly at the last green commit and say how many rounds you
  got. Never start a round you cannot finish and gate.
- **Guards get louder.** No-progress, regression and thrash all stop the whole
  run, not just the round. Nobody is watching, so a wrong fix must not get three
  more attempts.
- **Every round still ends green and committed.** The invariant that makes this
  safe to leave alone: whenever it stops, for any reason, the branch is at a
  gated commit.

Report at the end as usual — round-by-round lines plus the parked list. If
`~/.claude/skills/the-job/notify.sh` exists, ping it on finish and on any guard
trip, since the point of hands-off is not watching the terminal.

**Cost is the real constraint.** Round 1 alone is ~135 agents / 8.5M tokens on a
16-file PR; delta rounds are cheaper but not free. `until-clean` on a large PR
can run for hours and spend heavily. Use it when you are leaving the desk and
the branch matters — not as the default.

### Surviving the session

`until-clean` runs inside one session. To keep grinding across restarts, wrap it:

```
/loop /grill <target> until-clean
```

Each firing re-enters, re-syncs the base, and either finds work or reports clean
immediately (cheap when there is nothing to do). Stop it with the loop's own
stop, not by killing the session mid-round.

## Tiers

`ultra` applies to **round 1 only**. Rounds 2+ are always `default` — they
review a small delta, and ultra's loop-until-dry sweep on a two-file delta is
waste. Round-1 `ultra` is for a large or high-risk PR where a missed finding is
expensive; it is not the normal setting.

## Cost

Round 1 dominates: measured `default` on a 16-file PR = 135 agents / 8.5M tokens
/ ~67 min. Delta rounds are far cheaper (smaller diff, fewer candidates, fewer
verifiers), but budget for **round 1 plus roughly half of it again** for a
3-round grill.

Do not grill a one-line diff — use `/code-review high`. Do not grill code that
is not yet gate-green; fix the obvious first.

## Boundaries

- **Never merges.** Never promotes a draft PR. Never force-pushes.
- Pushes only when the user asked for a push flow, or when running under
  `the-job` (which owns its own push step).
- Works on the current worktree/branch. Never touches the main checkout when a
  worktree exists for the branch.

## Reporting

Per round, one line: `round r — k confirmed, k fixed, m parked, gate green, <sha>`.

Final report:
1. **Did it converge?** clean round / cap or hard wall hit / guard tripped — say
   which. Also say whether the branch was **rebased** during the run, and onto
   what — a pushed branch that got rebased needs `--force-with-lease` at the
   owner's next push.
2. Findings fixed, grouped by round.
3. **Parked**, with reasons — the part the user must decide on.
4. Refuted count (one line).
5. `cleared` highlights from the last round — what was attacked and held.
