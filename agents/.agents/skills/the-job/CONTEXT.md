# the-job

Autonomous work crew for `Presight-AI/vantage-frontend`: drains assigned issues into draft PRs, defends open PRs, and escalates genuine decision points to Telegram instead of stalling.

## Language

### Execution

**Tick**:
One invocation of the-job. Does one unit of work (or one sweep step), reports, stops.
_Avoid_: run, cycle, iteration

**Unit**:
One issue or PR worked end-to-end — the atom of scheduling, locking, and reporting.
_Avoid_: task, job, item

**Promotion sweep**:
The tick-start pass that promotes qualifying draft PRs to ready-for-review.
_Avoid_: promotion check

### Unit states

```
queued → working → shipped
              ↘ asked → answered → working (bucket 0) → shipped
                     ↘ expired    (revivable by answering)
              ↘ bailed            (needs human work, not an answer)
```

**Queued**:
Assigned, untouched, passes the availability filter.

**Working**:
Worktree exists — the worktree is the in-flight lock.
_Avoid_: in progress, active

**Asked**:
Set aside with at least one open Ask; other units proceed.
_Avoid_: parked, waiting, blocked

**Answered**:
A Reply is bound to the unit's Ask; resumes as bucket 0 on the next tick.

**Shipped**:
Terminal success — draft PR opened, comments addressed, or CI fixed.

**Bailed**:
Terminal give-up on a defect: no reply unblocks it; needs spec or human work. Always loud (issue comment + ping).
_Avoid_: failed, stuck

**Expired**:
Terminal give-up for silence: Asks exhausted unanswered. Cure is an answer — revived by `/the-job N`, unlike bailed.
_Avoid_: timed out, abandoned

**Parked** (reserved):
A review/grill *finding* recorded in the PR body and not acted on. Findings park; units never do.

### Escalation

**Ask**:
A closed-option question sent to Telegram, bound to a unit, carrying a Code. Open-ended questions are never Asks — they bail.
_Avoid_: escalation, question, ping

**Code**:
The 5-character reply key on every Ask, at least one digit (so the telegram plugin's permission regex can never eat the reply).

**Reply**:
The user's answer, bound to an Ask by its Code.
_Avoid_: answer, response

**Revive**:
Manually restarting an expired unit by answering it (`/the-job N`).

### Reply transport

**Drain**:
The no-live-poller path: one read-only `getUpdates` (no offset — never acknowledges) at tick start, results persisted to the Inbox.
_Avoid_: poll, fetch

**Capture**:
The live-poller path: a session that receives a `<channel>` reply appends it to the Inbox.

**Inbox**:
Per-message reply files (atomic tmp+rename), written by Drain and Capture, consumed at tick start.
_Avoid_: queue, mailbox

**Ledger**:
Per-Ask state files: question, Code, ask timestamps, listener uptime, Reply.
_Avoid_: inbox (the Ledger tracks Asks; the Inbox holds raw Replies)

**Watermark**:
Per-chat high-water `message_id` that makes duplicate delivery inert.
