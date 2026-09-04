---
name: the-job
description: Autonomous work crew — drains YOUR assigned issues into review-ready draft PRs and defends your open PRs by addressing review comments and fixing red CI. Use when the user says "/the-job", "pull the job", "put in work", "work my queue", "handle my PRs/issues", or wants hands-off progress on their assignments. Escalates closed-option decisions to Telegram (Asks) instead of stalling; promotes clean drafts to ready. Comments-first, gated, WIP-capped at 4 open PRs. Draft-PR-and-stop per unit of work — never auto-merges.
metadata:
  short-description: Address my PR review comments + fix red CI, then open draft PRs for my oldest assigned issues. Asks me on Telegram at real decision points. Gated, capped, no auto-merge.
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, Workflow, Skill, Task, ScheduleWakeup
---

# the-job

The crew pulls the job while you're out. One invocation = **one unit of work** (address one PR's comments, fix one red CI, or open one draft PR), then report and stop — so it's auditable and loopable/schedulable.

Repo: `Presight-AI/vantage-frontend`. Main checkout: `/Users/dosmukhamed.zhanibek/work/vantage-frontend`. Worktrees are siblings: `/Users/dosmukhamed.zhanibek/work/vantage-frontend.<branch>`. Base branch: `origin/develop`. Your login: `dosmukhamed-zhanibek`.

`gh` CLI for ALL GitHub reads/writes. **Never GitHub MCP tools for comments** (CLAUDE.md ban).

**Canonical terms** (unit states, Ask/Reply/Drain/Capture/Inbox/Ledger/Watermark) live in [CONTEXT.md](CONTEXT.md); load-bearing decisions in [docs/adr/](docs/adr/). Use those words exactly — "parked" is for findings, never units.

## Args

- **No arg (default)** → work my **untouched assigned issues**: issues assigned to me that have **no local worktree and no remote branch** (see Availability filter). Do the single highest-priority unit per the priority order below, then stop.
- `loop` → keep doing units until the queue is dry or a stop condition hits (see Loop/Schedule).
- A PR number (e.g. `/the-job 6062`) → address that PR's comments / red CI only.
- An issue number or **list** (e.g. `/the-job #5575` or `/the-job 5575 5590 5601`) → work exactly those, in order (bypass the pick step; PR cap still applies). Explicit numbers override the availability filter — if you name it, it gets worked. Naming an **expired** unit is the Revive path: reuse its worktree, apply the stored Reply from the Ledger if one arrived late, set the Ledger entry `status: "revived"`, continue from where it parked.
- `detach` (combinable: `/the-job detach`, `/the-job detach 5575 5590`, `/the-job loop detach`) → don't work the unit here; hand each unit to its own session in its own worktree, via whichever transport the surface supports (see Detached mode).

### Availability filter (the default queue)
An assigned issue is **available to pick** only when it has neither a local worktree nor a remote branch — otherwise it's already in flight and gets skipped.
```bash
# local worktrees (any branch containing -<N>-)
wt list
# remote branches referencing the issue number
git -C /Users/dosmukhamed.zhanibek/work/vantage-frontend ls-remote --heads origin | grep -E "[-/]${N}[-/]" || true
```
An issue is in-flight if EITHER hits. Also skip if an open PR of mine already references it. Only truly-untouched issues enter the default queue.

## Notifications (Telegram — you watch progress live)

Ping Telegram at every state change so you know what's happening hands-off. Helper (non-fatal — a failed ping never breaks the job):
```bash
~/.claude/skills/the-job/notify.sh "<message>"
```
It reads the bot token + your chat id from `~/.claude/channels/telegram/`. Send a ping at each of these events (Markdown ok, keep terse, include the PR/issue url so it's tappable):

| When | Message shape |
|---|---|
| **Run start** | `▶️ the-job start — <mode: default/loop/#N>` |
| **Picked an issue** | `🎯 started #<N> — <title>` (right after worktree created) |
| **Draft PR opened** | `✅ draft PR — #<N> → <pr-url>` (note if `run-full-e2e` added) |
| **Addressed PR comments** | `💬 PR #<P> — addressed <k>, parked <m> → <pr-url>` |
| **Fixed red CI** | `🔧 PR #<P> — CI fixed → <pr-url>` |
| **Bail** | `⚠️ bailed on #<N> — <one-line blocker>` |
| **Ask sent** | sent by `ask.sh` itself (`❓ ask [<code>] — …`); no extra ping |
| **Answered resume** | `🅰️ resumed #<N> — applying your reply` |
| **Expired** | `⌛ ask expired — #<N> parked unanswered; revive: /the-job <N>` |
| **Late reply** | `⌛ [<code>] expired before your reply landed — revive: /the-job <N>` |
| **Promoted** | `🚀 promoted to ready — PR #<P> → <url>` (notification, never a question) |
| **Run end** | `🏁 done — <x> PRs opened, <y> comments handled, <z> asked, <w> bailed` |

Rules: one ping per event, not per file. Bails and run-end are the important ones for a scheduled run — never skip those. Parked findings go in the run-end summary.

## Tick start (mechanics before any bucket)

Every tick begins with:
```bash
~/.claude/skills/the-job/tick.sh
```
It does the Reply plumbing (coverage accounting → read-only Drain → Inbox→Ledger binding — ADRs 0001–0003) and prints an action summary. Act on it in this order:
1. `answered` → those units are **bucket 0** below.
2. `reaskDue` → `ask.sh --reask <code>` each.
3. `expireDue` → expire flow: Ledger `status: "expired"`, comment on the issue/PR (mechanism + "revive with `/the-job <N>`"), Telegram-ping ⌛, unit released from the run (worktree stays — it is still the in-flight lock; the revive contract is the release valve).
4. `lateReplies` → pushback ping (`⌛ [<code>] expired before your reply landed — revive: /the-job <N>`); the Reply is already stored in the Ledger for the revive.
5. `unbound` → a message with no Code: if **exactly one** Ask is open, bind it to that Ask (echo-confirm by ping: `🔗 took "<text>" as the answer to [<code>]`); otherwise ping the open-Ask list and leave the file. Non-reply chatter: ignore; delete unbound files older than 7 days.
6. **Promotion sweep** (own section below).

Then pick a bucket.

## Priority order (what to do each run)

Higher value = closer to merge. Always do the top non-empty bucket:

0. **Answered units** — a unit whose Ask got a Reply resumes first. **Cap-exempt** (may open PR #5): the answer is fresh and the investigation already paid for. Before applying the Reply: fetch, `Skill: git-rebase-sync` if the base moved, and re-validate the 3b-bis brief — a days-old blast-radius claim may be false against moved develop. A resumed unit that hits the **same wall** again bails (no re-ask ping-pong).
1. **My open PRs with unaddressed review comments** — drain reviewer feedback first.
2. **My open PRs with red CI** — fix my own breakage.
3. **New issue** — only if `open-PR count < 4`. Pick oldest issue **assigned to me**, open a draft PR.

If buckets 0–2 empty and bucket 3 is capped → stop, report "queue full, N PRs awaiting your review".

## Asks — escalate decisions, bail on defects

The test is **decision-vs-defect**: escalate only when a one-line human answer unblocks the unit, and only when the question is expressible as **numbered options** (A/B/C or yes/no with the consequence stated). An open-ended "what should I do?" answered from a phone is just a second vague sentence — that's a bail, not an Ask.

| Situation | Ask (closed options) |
|---|---|
| Issue too vague — but readings enumerable | `1 = reading A / 2 = reading B / 3 = drop` |
| Intent ambiguous (expected-vs-actual unclear) | the 2–3 concrete interpretations |
| Grill hits round cap, findings still open | `1 = ship with parked list / 2 = keep grinding / 3 = drop unit` |
| Vague/subjective review comment | enumerated readings (see 1b) |
| Would-be "won't do" to a reviewer | `1 = refuse with this draft reasoning / 2 = implement as asked` |
| e2e re-fails same way after one rerun | `1 = flake, proceed / 2 = investigate as regression / 3 = leave for you` |
| Two plausible seams for the fix | `1 = seam A (<tradeoff>) / 2 = seam B (<tradeoff>)` |

Mechanics:
```bash
CODE=$(~/.claude/skills/the-job/ask.sh "issue-<N>" "1 = … / 2 = …")   # sends the ping, writes the Ledger, prints the Code
```
- **Non-blocking**: send the Ask, set the unit **asked** (worktree stays = lock), move to the next unit. The Reply comes back through `tick.sh` on a later tick (Drain when no live poller, Capture when one exists — ADR 0002; the Capture rule lives in the global `~/.claude/CLAUDE.md`).
- **Budget**: max 2 Asks per unit — `ask.sh` refuses the third (exit 2) → bail. `ask.sh` exit 1 (no token, send failed) → bail; an Ask that can't be delivered must not park a unit.
- Codes carry a digit so the telegram plugin's permission regex can never eat the reply; you answer `<code> <option>`.
- Expiry runs on **listener uptime**, not wall clock (ADR 0003): re-ask once on resume-after-gap or ≥24h coverage; expire after ≥2 delivered Asks + ≥24h coverage unanswered + ≥72h wall. All computed by `tick.sh` — never hand-time it.
- State: `state/ledger/<code>.json` (Asks), `state/inbox/` (raw Replies), `state/seen/` (Watermarks). All outside every repo.

### PR cap = 4 (backpressure)
Before bucket 3, count my open non-draft-or-draft PRs:
```bash
gh pr list --repo Presight-AI/vantage-frontend --state open --author "@me" --json number,isDraft,reviewDecision,statusCheckRollup
```
If `count >= 4` → **do not pick a new issue**. Force focus onto buckets 0–2. WIP-limit: finish before you start. (Bucket-0 resumes are exempt — see Priority order.) Cap-hit is a **ping**, never an Ask: only your merges relieve it; promotion doesn't reduce the open count.

## Promotion sweep (draft → ready, autonomous, ping-only)

Part of tick start. For each of my open **draft** PRs, promote iff ALL hold:
- `statusCheckRollup` on the **head SHA**: every check completed and `SUCCESS` — not the local gate (which is unit-only by design; integration/e2e run only in CI), and `PENDING` is not green;
- `mergeable` is not `CONFLICTING` against develop (conflicting → skip + note; resolving it is bucket work, not sweep work);
- the PR-body **Known / parked** section is empty — that section is the source of truth for parked findings, not in-run memory;
- **zero human activity since my last push** — no commits, comments, reviews, or a ready→draft demotion (check the timeline; a demotion by you is permanent: never re-promote that PR);
- this PR was **never promoted before** — record in `state/promoted/<pr-number>`; at most one promotion per PR, ever.

On promote: `gh pr ready <PR>`, re-request the known reviewer, ping `🚀 promoted to ready — PR #<P> → <url>`. A notification, never a question — un-ready is one click if you disagree.

---

## Bucket 1 — Address review comments on my PRs

### 1a. Find the PR needing attention
```bash
gh pr list --repo Presight-AI/vantage-frontend --state open --author "@me" \
  --json number,title,headRefName,reviewDecision,updatedAt
```
Pick the one with `reviewDecision == CHANGES_REQUESTED` or unresolved review threads, oldest `updatedAt` first. Fetch full comment set:
```bash
gh pr view <PR> --repo Presight-AI/vantage-frontend --comments
gh api repos/Presight-AI/vantage-frontend/pulls/<PR>/comments --paginate   # inline review comments
```
Read **every** comment start to finish (same discipline as verify-issue Step 2). Skip comments you already addressed (pushed after their timestamp). To understand the code a comment points at, use `codegraph explore` first (run from the main checkout — index isn't in worktrees).

### 1a-bis. Parallel triage across candidate PRs (when more than one qualifies)
If more than one open PR has `CHANGES_REQUESTED` or unresolved threads, don't commit to "oldest" blind — a stale question-only thread can sit ahead of a fresh, substantive change-request. PR A's comments don't inform PR B's read, so this is a real edge-free fan-out, not a forced one. Bounded by the PR cap (≤4 candidates) — cheap. Read-only, no `isolation: 'worktree'` (nothing is written yet):

```js
export const meta = {
  name: 'the-job-pr-triage',
  description: 'Classify unresolved comment threads across candidate PRs before picking one',
  phases: [{ title: 'Triage' }],
}
phase('Triage')
const results = await parallel(candidatePRs.map(pr => () =>
  agent(`Fetch every comment/review thread on PR #${pr.number} (gh pr view --comments, gh api .../pulls/${pr.number}/comments) and classify each against the 1b table (change-request / question / vague / nit). Return counts per kind and whether any thread is a clear, unaddressed change-request.`,
    { label: `pr-${pr.number}`, schema: TRIAGE_SCHEMA })
))
```
Pick the PR with a clear unaddressed change-request, oldest `updatedAt` among those; if none has one (all question/vague/nit), fall back to oldest `updatedAt` as before — it's still bucket 1 work, just a reply or an Ask instead of a code change. Proceed into 1b/1c for the picked PR only — the other candidates' triage results are read-only context, not a mandate to work them this unit.

### 1b. Triage each comment — NOT everything is a code change
| Comment kind | Action |
|---|---|
| **Clear change request** ("rename X", "handle null", "use logical prop") | Implement it. |
| **Question / rationale ask** ("why this approach?", "did you consider Y?") | Reply with the reasoning. **No code** unless the answer is "you're right, changing it". |
| **Vague / subjective / out-of-scope** | **Ask** with 2–3 enumerated readings of what the reviewer might mean. Genuinely un-enumerable → park the finding in the report. Never guess-code it. |
| **Nit / praise / approval** | No action. |

### 1c. Implement + gate in the PR's worktree
Switch to that PR's worktree (reuse if it exists, else create off its head branch — see Worktree section). Make the changes. Rebase on fresh base if stale (`Skill: git-rebase-sync`). Run the **full gate** (see Gate section).

**Then grill your own fix** — `Skill: grill "review the changes since <sha-before-my-fixes>"`, scoped to what you just changed, `rounds:2`. Comment-driven fixes are written fast under someone else's framing and land straight on a PR a human already reviewed; they get the least scrutiny and deserve some. Scoped rounds are cheap. Skip only for a genuinely trivial edit (a rename, a typo, a logical-prop swap) — say in the report that you skipped and why.

Then tidy comments (`Skill: tidy-up`) and commit (`Skill: caveman-commit` — no Claude co-author).

### 1d. Reply + push
Push. Reply to each addressed thread — **your style, baked from memory**:
- **No praise** ("good catch" banned). State the fix directly.
- **No blame** — never cite which PR/commit introduced it; mechanism only.
- **Refs = PRs/commits, never file:line** (line refs rot).
- Sign nothing. Terse + factual so it reads as you.
- "Won't do" → **Ask first** (`1 = refuse with this draft reasoning / 2 = implement as asked`). Declining a colleague publicly is a position taken in your name — never refuse unattended. Implementing what they asked stays autonomous.

Re-request review:
```bash
gh pr edit <PR> --repo Presight-AI/vantage-frontend  # re-request via API if reviewer known
```
Report the PR, what you changed, what you parked. **Stop.**

---

## Bucket 2 — Fix red CI on my PRs

From the `statusCheckRollup` above, pick my PR with a failing check. Pull the failure:
```bash
gh pr checks <PR> --repo Presight-AI/vantage-frontend
gh run view <run-id> --repo Presight-AI/vantage-frontend --log-failed
```
Switch to its worktree, reproduce locally (usually the Gate below catches it), fix, gate, commit, push. Report + stop.

A CI fix that changes **product code** (not just a test, config or lockfile) gets the same scoped grill as bucket 1 — `Skill: grill "review the changes since <sha>"`, `rounds:2`. A green CI proves the build stopped complaining, not that the fix is right.

**E2e failures = flake-aware, not blind chase.** e2e/component are known-flaky (memory: e2e flake baseline, screenshot suite disabled). Before "fixing" an e2e red: check if it's an infra flake (OIDC network-flap, cold backend, `net::` error, baseline drift on the disabled suite) vs a real regression your diff caused. Real regression → fix. Flake unrelated to my diff → re-run the job (`gh run rerun <run-id> --failed`) once; if it re-fails the same way, **Ask**: `1 = treat as flake, proceed / 2 = investigate as regression / 3 = leave for you` — unit goes asked, next unit. Never edit test baselines to force green.

---

## Bucket 3 — Open a draft PR for my oldest assigned issue

### 3a. Pick (only if PR cap not hit)
```bash
gh issue list --repo Presight-AI/vantage-frontend --state open --assignee "@me" \
  --search 'sort:created-asc' --limit 30 \
  --json number,title,author,labels,url,projectItems
```
Skip, in order:
- issues **failing the Availability filter** (already have a local worktree or remote branch, or an open PR of mine references them) — see Args.
- issues **authored by `fosemberg`** (his tickets need his own verdict — memory rule).
- issues in the **DONE** column of Synergy Development (project #12) — already resolved.

Take the oldest surviving issue. Creating its worktree/branch (step 3c) is what marks it in-flight — the Availability filter then excludes it from every later run, so re-runs never double-grab. Optionally also move its card to **In Progress** for board visibility.

### 3b. Investigate (reuse verify-issue's investigation half)
Read body + **every comment** (`gh issue view <N> --comments`). Extract surface (map to CLAUDE.md Component list), repro/acceptance, expected-vs-actual. **Locate/understand the code with CodeGraph FIRST** (repo is indexed — `.codegraph/` at root; global CLAUDE.md rule):
```bash
codegraph explore "<symbol names or the surface question>"   # verbatim source + call paths, incl. dynamic-dispatch hops grep misses
```
Run it from the **main checkout** (`/Users/dosmukhamed.zhanibek/work/vantage-frontend`) — the index lives there, NOT in the sibling worktrees. Fall back to Grep/Glob/`Task` Explore only for what CodeGraph can't answer. Trace the real path, not the first file. Same rigor as `verify-issue` Step 2–3 — but now you FIX, then edit in the worktree.

### 3b-bis. Design brief — BEFORE any edit (cheap; this is what stops the scrub loop)

Reviewing is how you find defects; the brief is how you don't write them. One agent, before the first edit. Write it down — it becomes the spec `/grill` grades in 3d.

Items 2 and 3 below are independent reads — `codegraph explore` doesn't need the grep results and the grep doesn't need the codegraph output — so run them in parallel via `Workflow` instead of two sequential tool calls, then write items 1/4/5 yourself once both are in hand (they need the whole picture: issue text + both research streams, not a sub-agent's slice). Read-only, main checkout only (codegraph's index isn't in worktrees), no `isolation: 'worktree'`:

```js
export const meta = {
  name: 'the-job-brief-research',
  description: 'Parallel blast-radius + parallel-sites research before writing the design brief',
  phases: [{ title: 'Research' }],
}
phase('Research')
const [blastRadius, twins] = await parallel([
  () => agent(`codegraph explore the symbols this fix touches: <name them>. Return callers, dependents, and whether each has covering tests.`, { label: 'blast-radius' }),
  () => agent(`Fingerprint-grep the repo for the same enum/guard/helper this fix needs to change, done elsewhere: <name the pattern>. Return each site as file:line + a one-line description of the twin.`, { label: 'parallel-sites' }),
])
```

1. **Root cause + seam.** The reason, not the symptom. Name the layer the fix belongs at. A fix at the first file that reproduces gets re-found by the altitude angle every round.
2. **Blast radius.** From `blastRadius` above — callers, dependents, whether they have covering tests. Decide up front what else must change.
3. **Parallel sites.** From `twins` above — the same enum handled elsewhere, the same guard written elsewhere, the same helper copied elsewhere. Finding twins before writing is free; after writing it costs a whole round (it's the highest-yield angle in the review corpus).
4. **Constraints for THIS change**, concrete, not principles:
   - **ownership** — which boundary must not be crossed (no render concern into a store, no feature import from `core/`, one registration site not three)
   - **determinism** — what must give the same answer twice (no clock/random reaching state, ties get a tiebreaker, tests pinned)
   - **cost** — which path is hot here and what must not be added to it
   - **simplest form** — the smallest shape that does the job; if the plan is bigger, say why
5. **Out of scope** — what you will NOT touch. This is the leash on drive-by changes.

Bail here if the brief can't be written: an issue whose root cause you can't name is not implementable yet — comment on it and bail (Bail-safe), don't code toward a guess. Two exceptions become **Asks** because they reduce to enumerable options: the intent is ambiguous between 2–3 concrete readings, or two plausible **seams** both hold (Ask with the tradeoff each carries). Root-cause-unnamed stays a bail — no reply names it for you.

### 3b-ter. Red test first

Turn the issue's **literal symptom sentence** into a failing test (`Task: test-author`; level per `.claude/rules/testing.md`). Red→green is the only proof the fix works — the gate proves nothing else broke, never that the thing works. If the symptom genuinely can't be expressed as a test at any level (real layout, live backend, permission the local env lacks), say so in the PR body and move on; don't fake a proxy assertion.

### 3c. Worktree + implement
Create worktree off fresh `origin/develop` (Worktree section). Branch: `bugfix-<N>-<slug>` if labeled `bug`, else `feature-<N>-<slug>` (slug = lowercased title, non-alnum→`-`, first ~6 words).

Implement **against the brief** — the named seam, the named twins, the named constraints, nothing on the out-of-scope list. Plus the repo patterns: MobX store conventions, Tailwind logical props (ps/pe/ms/me — RTL), `notifyError` in catches, i18n `t()` in render only, no `any`/`as`. Follow CLAUDE.md; it overrides defaults.

If implementing shows the brief was wrong (the seam doesn't hold, the blast radius is bigger), **update the brief and say so** — a stale brief silently becomes a set of false claims for 3d to grade.

### 3d. Gate + grill (the self-supervision — see Gate section)
- Full gate must pass green, and the 3b-ter test must be **green now** (it was red before the fix).
- `Skill: grill` on own diff. It runs the review→fix→re-review loop with its own gate, guards and round cap — do not hand-roll rounds here.
  - Feed it the brief: the 3b-bis constraints and the fix claims are what it grades ("this stayed at the store seam / this stayed deterministic — did it?").
  - Its **park** list and any guard trip (no-progress, regression, thrash) come back to you — parked findings go in the PR body, a tripped guard is a **bail** (mechanical defect, no reply fixes it).
  - Round cap hit with findings still open → **Ask**: `1 = ship with parked list / 2 = keep grinding / 3 = drop unit`.
- `Skill: tidy-up` comments, `Skill: caveman-commit`.

### 3e. Draft PR + move card
```bash
gh pr create --repo Presight-AI/vantage-frontend --draft --base develop \
  --title "<type>(<scope>): <summary> (#<N>)" \
  --body "<what + why, mechanism only — NO blame, closes #<N>>"
```
- **Draft**, always (v1). Parks safely; you promote when you've reviewed.
- Body: mechanism only, no "PR X broke this" (memory: no-blame). Include a short **Known / parked** section listing what grill parked and why, and note if the 3b-ter test couldn't be written — a reviewer reading "nothing parked" should be able to trust it.
- **Full-e2e decision (label-driven).** The local gate is unit-only — e2e runs in **CI on the PR**, never locally (flaky/slow/headless; screenshot suite disabled on develop). CI runs `e2e-smoke` by default; the **`run-full-e2e`** label (sticky, PR-scoped) flips CI to the full `e2e` tier. Add the label when the change warrants full coverage:
  ```bash
  gh pr edit <PR> --repo Presight-AI/vantage-frontend --add-label run-full-e2e
  ```
  Add it when: the diff is **multi-module / cross-cutting**, touches a **shared surface** (routing, auth, app-store/WS, a shared wrapper), or changes **user-flow behavior** an e2e spec covers. Leave smoke-only for narrow, single-surface fixes. When unsure on a bug-fix that changes behavior → add it (cheap insurance).
- Move card to **Review**. Report PR url + one-line summary + whether full-e2e was requested. **Stop.**

### 3f. Showcase video — OPTIONAL, gated, NEVER parallel
A proof recording (`Skill: showcase-fix`) is expensive (drives the real app via Playwright+Keycloak, slow, flaky) and only adds value for a **visually demonstrable** fix. Record one ONLY when ALL hold:
- the issue is a **bug** with a **clear visual repro** that renders in the local harness (a UI change a reviewer can SEE);
- the repro is **reproducible locally** — the app/env can actually reach the before/after state (no live-only backend, no special permission/role, no data the local env lacks);
- the diff **changes visible UI behavior** (not a pure logic/perf/type/test-only fix).

Skip it (the default) when any fail — e.g. #6152 needed live `dataeng` in a real workspace, which the local env can't stage, so **no showcase**. When you skip, say why in the report; don't silently drop it.

**NEVER run showcase-fix in parallel — including across OTHER sessions.** It owns the display, ports, a single app instance, and ffmpeg; two at once corrupt both recordings. Collisions happen cross-session (many `claude` sessions run at once), so within-run serialization isn't enough. Use the **cross-session FIFO coordinator** — `~/.claude/skills/the-job/showcase-queue.sh` (atomic mutex + timestamped queue + stale-lock reclaim):
```bash
Q=~/.claude/skills/the-job/showcase-queue.sh
"$Q" status                                  # monitor: who holds it, is a recording live, who's in line
ticket=$("$Q" enqueue "6152-dq-tree")        # take a numbered place in line
# poll until it's your turn AND the lock is free AND no foreign recording is live:
until "$Q" try-acquire "$ticket"; do sleep 20; "$Q" status; done
#   ... run Skill: showcase-fix ...
"$Q" release "$ticket"                        # ALWAYS release, even on failure
```
`try-acquire` returns non-zero (keep waiting) unless you're the **oldest ticket** AND the mutex is free AND `pgrep` finds no foreign `playwright/ffmpeg`. It reclaims a lock whose owner pid is dead so a crashed session can't wedge the line; `release` only frees a lock you own — **never kill or release someone else's recording.** Don't wait forever: cap the wait (a few polls); if still not your turn, **skip the showcase** and note it in the report — the PR is already open, the video is a nice-to-have. Run `"$Q" dequeue "$ticket"` if you give up so you leave the line cleanly.

---

## Gate (hard wall — same as CI `quality-check`, scoped to diff)
No PR opens / no "done" claim until this is green.
```bash
BASE=origin/develop
FILES=$(git diff --name-only --diff-filter=d "$BASE"...HEAD | grep -E '\.(js|jsx|tsx|ts)$')
npm run type-check
if [ -n "$FILES" ]; then
  echo "$FILES" | xargs env ESLINT_TYPED=1 npx eslint --quiet   # CI's type-aware lane
  echo "$FILES" | xargs npx prettier --check
fi
npm run knip                                                     # add targeted ignores per CLAUDE.md, don't delete generated files
npm run test:unit
```
Red on any step → fix or **bail** (see below). Never open a PR over a red gate.

## Bail-safe (when hands-off, the machine must fail loud not silent)
Bail = **defect**, Ask = **decision** (see Asks section). Bail when no reply on earth unblocks: root cause unnameable (3b-bis), stuck after real effort, gate won't pass after honest attempts, grill trips a guard (no-progress, regression, thrash), the would-be Ask is open-ended (not expressible as numbered options), the ask budget is exhausted, a resumed unit hits the same wall again, or `ask.sh` itself can't deliver.
On bail:
- Do **not** open/force a bad PR.
- Post a comment on the issue/PR: what you found + the exact blocker (mechanism, no blame).
- Leave the card where it is (or move back to Todo).
- **Telegram-ping the bail** (`notify.sh "⚠️ bailed on #<N> — <blocker>"`) and report it prominently to the user.
- Move to the next unit only in `loop` mode.

## Budget cap (loop/schedule only)
In `loop` mode, respect the token budget. Stop picking new units when `budget.remaining()` is low. One stuck issue must not burn the run — the 3-round self-review cap + bail-safe enforce this per-unit.

---

## Worktree (isolation — mirrors /check, but this skill IMPLEMENTS)
Each unit = its own worktree = its own branch. Never touch the main checkout's working tree. Reuse the worktree if one exists for the branch; else:
```bash
git -C /Users/dosmukhamed.zhanibek/work/vantage-frontend fetch origin
wt switch --create <branch>    # off origin/develop for new issues; off the PR's head for bucket 1/2
```
By default this skill does the work **in-process** (no new tmux window / no nested Claude) so it can run headless under `/schedule` — a cron box has no tmux server and no way to reach a nested session. `detach` opts out of that; everything else is unchanged. Never `wt remove`/`--force`.

**Node_modules + committing — the worktree pnpm hazard (learned on the #6152 run, follow exactly):**
- `wt` creates the worktree with **NO `node_modules`**. Symlink it to main for read-only gate tools: `ln -s ../vantage-frontend/node_modules node_modules`, then run tools via `node_modules/.bin/<tool>`.
- What works over the symlink: **type-check (tsc), eslint, prettier, knip**. What does NOT: **vitest integration tests** — Vite's fs-allow denies the symlinked (main-resolved) paths (`Error: Denied ID …`). Don't fight it; let **CI** run the integration/e2e tests and note it in the PR.
- **NEVER `pnpm i` / `npm install` in the worktree**, and **NEVER commit/push through husky here.** The husky **pre-commit** hook runs a pnpm dep-status check that tries to **purge the modules dir** — with `node_modules` symlinked to main, that would **corrupt the main checkout**. It aborts on no-TTY (`ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY`) so nothing breaks, but the commit fails.
- **Correct commit sequence:** run the gate manually (green) → `rm node_modules` (remove the symlink, kills the corruption vector) → `git commit --no-verify` → `git push --no-verify`. The `--no-verify` is safe *because you already ran the exact gate by hand*. Never `--no-verify` without having run the gate.
- After any failed hook run, verify main is intact (`ls main/node_modules/.bin/{eslint,vite}`) and do **not** pop the lint-staged backup stashes (working tree already holds your changes; git-stash daemon hazard).

## Detached mode (`detach`) — hand the unit to its own session

Opt-in. This session picks and scopes the unit, writes a brief, hands it to a **separate session that owns it end to end**, and stops. Your session stays free and each unit gets its own context.

**Pick the transport by what the surface actually has — never assume a terminal.** Claude Code runs in the CLI, the desktop app, the web app and IDE extensions; only one of those has tmux. Probe, don't presume:

| Probe | Transport | Why |
|---|---|---|
| `$TMUX` is set — this session is running **inside** tmux | **tmux window + fresh interactive Claude** (below) | Best: watchable live, survives this session, you can type into it when it bails. |
| `$TMUX` unset but Bash works — desktop app, IDE extension, plain shell | **Headless Claude in the worktree**, backgrounded: `Bash(cd <worktree> && claude -p "Read <brief> and carry it out", run_in_background: true)` — you get a completion notification when it exits | Same isolation, no terminal needed. One-shot: it can never *wait* for you — decisions go through `ask.sh` + exit (a later tick resumes the unit), defects bail by commenting on the issue and exiting. Never spawn into a tmux server you aren't attached to just because `tmux info` succeeds — the window would be invisible to whoever asked. |
| Neither (or you want it in-session) | **`Agent` tool with `isolation: 'worktree'`** | Portable everywhere. Costs this session's context for the report, and the agent's worktree has no `node_modules` — the gate needs the symlink dance (Worktree section) and integration tests must be left to CI. |
| Running under `/schedule` / cron | **In-process** — ignore `detach` entirely, say so in the report | Nothing is there to watch a spawned window, and a headless child can't be supervised by a job that has already exited. |

**On a cloud surface** (claude.ai/code, a remote agent) there is no `~/work` and no local env — the sibling-worktree layout, the `node_modules` symlink and every path in this skill assume the Mac. Work in-process in the sandbox clone, install deps there, and say in the report that the local-env-dependent steps (showcase, integration lanes) were skipped.

The brief and the hard rules are identical across all three — only the launcher differs. Whichever you pick, name it in the report so the user knows where the work went.

Each step is **idempotent** — re-running `detach` on the same unit must attach to what exists, never duplicate it. The **worktree is the lock** (the Availability filter reads it), so it works for every transport, not just tmux.

### Transport A — tmux window (when the probe says tmux is there)

```bash
MAIN=/Users/dosmukhamed.zhanibek/work/vantage-frontend
BRANCH=<bugfix-|feature-|fix-><N>-<slug>        # same naming as 3c; bucket 1/2 = the PR's head branch
WIN=job-<N>                                     # window name IS the idempotency key — keep it stable

# 1. worktree — reuse if the branch already has one
git -C "$MAIN" fetch origin
git -C "$MAIN" worktree list | grep -q "\[$BRANCH\]" && CREATE="" || CREATE="--create"

# 2. window — reuse if one is already named for this unit
if tmux list-windows -a -F '#{window_name}' | grep -qx "$WIN"; then
  # 3. Claude — start one only if the pane isn't already running it
  PANE_CMD=$(tmux list-panes -t "$WIN" -F '#{pane_current_command}' | head -1)
  case "$PANE_CMD" in
    claude|node) : ;;                                        # already working — leave it alone, report and stop
    *) tmux send-keys -t "$WIN" "claude '<handoff prompt>'" Enter ;;
  esac
else
  tmux new-window -c "$MAIN" -n "$WIN" \
    "wt switch $CREATE $BRANCH -x claude -- '<handoff prompt>'"
  tmux set-window-option -t "$WIN" remain-on-exit on
fi
```

`wt switch --create <branch> -x claude -- '<prompt>'` creates the worktree off fresh `origin/develop`, then replaces itself with Claude already running the prompt. Drop `--create` to reuse.

**Never send keys into a pane already running Claude** — you'd type into its prompt mid-turn. A live unit is left alone; report "already in flight" and pick the next one.

### Transports B/C — no tmux

Same worktree, same brief, different launcher. B: create the worktree first (`wt switch --create <branch>` from the main checkout), then `claude -p` inside it via a backgrounded Bash call. C: one `Agent` call with `isolation: 'worktree'` whose prompt is the read-the-brief line. Idempotency check for both is the worktree + an open PR/branch for the unit — if either exists, it's in flight; don't relaunch.

### The handoff brief (the whole reason this works)

The new session inherits **nothing** — not your investigation, not the issue text, not the CI logs you read. A one-line prompt produces a session that re-derives everything badly. Write a brief to `~/work/the-job-briefs/<BRANCH>.md` (outside every repo, so `git clean` can't take it) and make the prompt just:

```
Read /Users/dosmukhamed.zhanibek/work/the-job-briefs/<BRANCH>.md and carry out the task described in it.
```

The brief carries, at minimum:
- **What and why** — issue/PR number + url, the surface, the literal symptom sentence.
- **What's already established** — the investigation you did (CodeGraph findings, failing CI logs with the exact error text, which diagnoses are verified vs. guessed). Mark prior-session readings as *readings*, and tell it to re-verify before building on them.
- **The design brief** (3b-bis) if you got that far: root cause, seam, blast radius, twins, constraints, out-of-scope. This is what its `/grill` will grade.
- **The rules that don't travel**: draft PR only, never merge, gate must be green (paste the Gate block), `run-full-e2e` decision, rebase on `origin/develop` with `--force-with-lease` when the base moves, no Claude co-author trailer, comments carry no file:line and no blame.
- **How to escalate**: `ask.sh` usage + the closed-option rule (paste the Asks table) — a detached session Asks through the same Ledger, and its Replies come back through any tick's `tick.sh`. Its bail-by-commenting rule stays for defects.
- **What it must NOT touch** — other branches, other PRs, the main checkout.

### After spawning
Telegram-ping (`🎯 started #<N>` with the worktree path and window name), report window + worktree + brief path to the user, and **stop this unit here** — the spawned session owns it end to end, including its own gate, grill, draft PR and bails. In `loop detach`, the loop's next tick picks the *next* unit; the Availability filter already excludes the one now in flight (its worktree exists), so units never double-grab.

**Why not `Workflow` for this.** Workflow agents are fire-and-forget with a schema-shaped return: they can't hold an interactive bail, can't be resumed when the brief turns out wrong, and each `isolation: 'worktree'` agent lands in a worktree with no `node_modules` — so the gate needs the symlink dance per agent and integration tests still can't run. Workflow stays what it already is here: fan-out **inside** a unit (`/grill`, `/deep-review`), never the owner of one.

## Loop / Schedule (the hands-off cadence)
- Test by hand first: run `/the-job` a few times, watch it, tune what "assigned + ready" means and tighten the gate/bail. **Do not schedule until ~10 clean runs.**
- Then loop: `/loop /the-job loop` (self-paced) or wrap in `/schedule` as a nightly cloud cron. `/schedule` implies **in-process** — `detach` is silently dropped there (no tmux on the cron box); use `/loop /the-job loop detach` when you're at the machine and want the units fanned into windows.
- Each unit is one issue/PR end-to-end, then stop → the loop re-invokes for the next. Telegram-ping run-start and run-end (`🏁 done — …`) so a scheduled overnight run reports its summary even if you never open the terminal. Stop conditions: queue dry, PR cap hit with nothing in buckets 0–2, budget low, or first bail needing a human. Asked units do NOT stop the loop — that's the point: ask, park, next.
- **Cloud routines** have no `~/.claude/channels/telegram/.env` and no state dirs — Asks are impossible there. Revert to plain bail behavior on a cloud surface and say so in the report. Local headless cron is fine: Drain and `ask.sh` are plain curl.

## Hard rules
- **Never auto-merge.** Output is always a **draft** PR + card move. Merge stays human (irreversible + outward-facing).
- **Never touch the main checkout branch/worktree.** Worktrees only.
- **PR cap 4** — enforced before every new issue pick.
- **Skip fosemberg-authored issues** and **DONE-column** issues.
- `gh` CLI only for GitHub writes; **no MCP comments**.
- PR/issue comments: **mechanism only, no blame, no praise, refs are PRs/commits not file:line.**
- No Claude co-author trailer in commits.
- Green gate or no PR. Bail loud, never ship red.
- **Brief before code** (3b-bis) — no edits until the root cause, seam, twins and constraints are named. Prevention is ~1 agent; a review round is ~135.
- **Grill before PR** (3d) — and scoped-grill in buckets 1–2. Parked findings go in the PR body; a tripped guard is a bail, not a push.
- **Asks are closed-option only** — open-ended = bail. Budget 2 per unit; same wall twice = bail. Codes carry a digit (permission-regex-proof). Every tick starts with `tick.sh`; never hand-time expiry (ADR 0003).
- **Drain never sends an offset** (ADR 0001) — read-only, mutexed, any non-200 = a poller booted → stop. Never ack, never retry.
- **Promotion**: CI-green on head SHA (not local gate) + mergeable + nothing parked + no human activity since my last push; at most once per PR, never after your demotion. Ping, never a question.
- **Showcase-fix is optional, gated (visual + locally-reproducible bug only), and NEVER runs in parallel** — single-lane, serialized, one app instance at a time.
- **`detach` probes for its transport and is idempotent** — tmux is one surface among several (desktop/web/IDE have none); probe, fall back down the ladder, and under `/schedule` work in-process. Never spawn a second session for a unit already in flight, never send keys into a pane already running Claude. A detached unit is handed off with a written brief, never a one-line prompt.
