---
description: Fresh-agent code review loop. Fix bugs until clean or safety cap.
agent: general
subtask: true
---

Run autonomous review -> fix -> review loop for current repository.

Parse optional flags from `$ARGUMENTS`:
- `--effort <low|medium|high|ultra>` default `medium`
- `--max-rounds <number>` or `--maxRounds <number>` default `10`
- commits default `true`
- `--no-commit` disables round commits

Rules:
- Use `todowrite` early. Multi-step task.
- Keep whole loop inside this command subtask so primary session stays clean.
- Use fresh `task` subagent for each review round so review context stays independent.
- Review concrete bugs only: logic, state, async, type/API mismatch, null/edge-case, security, perf cliffs. No style-only nits unless they hide bug.
- Never revert unrelated user changes.
- Keep fixes minimal.
- Run targeted verification after each fix round when feasible.
- If commit mode enabled, inspect `git status`, `git diff`, and `git log --oneline -10` before committing. Stage only intended files. Use concise repo-style commit message mentioning review round.
- Do not treat empty post-commit worktree diff as proof code is clean. After a round commit, next review must inspect latest round commit or cumulative loop changes, not empty working tree.
- Do not clear main session between rounds. Fresh reviewer context is enough; clearing loop controller context loses findings, scope, and verification history.

Target selection:
- Round 1: if worktree has staged or unstaged changes, review current diff; otherwise review latest commit by default.
- Later rounds with commit mode on: review latest round commit, or cumulative changes since loop start if that is easier.
- Later rounds with commit mode off: review current accumulated worktree diff.

Process:
1. Parse flags from `$ARGUMENTS` and state chosen options before work starts.
2. For each round until clean or max rounds hit:
   - Launch fresh review subagent with `task`.
   - Reviewer instructions: read/search only, no edits, no destructive git, inspect target diff and nearby code, review one file at a time first then cross-file flows, return only concrete findings with file/line refs and short fix direction. If none remain, return literal `NO_BUGS`.
   - If reviewer returns `NO_BUGS`, stop loop successfully.
   - Fix every confirmed bug in main session.
   - Verify changed behavior with targeted tests, typecheck, lint, or other narrow checks when available.
   - If commit mode enabled, create round commit after verification.
3. Final output:
   - rounds used
   - findings fixed per round
   - verification run
   - whether loop ended clean or hit cap
   - residual risks if any

Start now.
