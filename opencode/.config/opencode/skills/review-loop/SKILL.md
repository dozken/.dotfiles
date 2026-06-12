---
name: review-loop
description: code review loop, fix bugs until clean, fresh reviewer each round, /code-review-loop. Use when user asks to review code repeatedly, fix all bugs, or keep reviewing until no bugs remain.
---

# Review Loop

Use for autonomous review -> fix -> review cycles.

Default behavior:
- slash command runs as subtask to avoid polluting main session
- fresh review subagent each round
- focus on concrete bugs, regressions, unsafe state/async flows, type/API mismatches, null handling, edge cases, perf cliffs
- no style-only findings unless bug hidden inside
- `effort=medium`
- `maxRounds=10`
- round commits enabled by default
- use `--no-commit` to keep fixes in working tree

Best practice:
1. Review current diff if worktree dirty.
2. If worktree clean, review latest commit unless user names different scope.
3. Keep controller context for whole loop. Do not use `/clear` between rounds.
4. Spawn fresh review subagent each round. Keep it read-only by instruction.
5. If round commits enabled, never use empty post-commit worktree diff as success signal. Review latest round commit or cumulative loop changes.
6. Fix confirmed bugs in main session with minimal edits.
7. Run targeted verification after each fix round.
8. Stop on `NO_BUGS` or safety cap.

Slash command:
- `/code-review-loop`
- `/code-review-loop --effort high`
- `/code-review-loop --max-rounds 6`
- `/code-review-loop --no-commit`

Manual behavior when slash command not used:
- perform same loop directly in session
- use fresh `task` reviewer each round
- summarize round count, bugs fixed, verification, residual risk
