---
name: ci-triage
description: red CI check to root cause to fix. Use when GitHub checks fail, a PR is red, ci broke, build/test failed, or user says triage ci, fix ci, why is ci red. Pairs with git-ship.
---

# CI Triage

Turn a red GitHub check into a root cause and a fix. Closes the loop git-ship only watches.

Use `todowrite` early. Multi-step.

## Locate the failure

1. `gh pr checks` — list checks, find failing ones (or `gh pr checks --watch` if still running).
2. Get the failed run: `gh run list --branch <branch> --limit 5`.
3. Pull logs of the failed job only: `gh run view <run-id> --log-failed`.
   - If too noisy, `gh run view <run-id>` first to find the failing job, then `gh run view --job <job-id> --log-failed`.

## Find root cause

- Read the failing step's log tail — quote the exact error.
- Map error to local code/test. Reproduce locally with the narrowest command (single test, single lint target, single build module) before editing.
- Distinguish failure class:
  - **Real defect** — fix the code.
  - **Flaky/infra** (timeout, network, runner) — re-run once: `gh run rerun <run-id> --failed`. Do not "fix" code for flakes; report it.
  - **Stale base** — branch behind `origin/develop`; rebase (hand to git-ship) rather than patch.
  - **Generated/lockfile drift** — regenerate, do not hand-merge.

## Fix and verify

- Minimal edit. Never touch unrelated changes.
- Re-run the same narrow local command to confirm green before pushing.
- Commit repo-style conventional message, push `--force-with-lease` only if history rewritten, else plain push.
- `gh pr checks --watch` until terminal.

## Output

- failing check + exact error quoted
- root cause + failure class
- fix (files) or rerun reason
- local verification run
- final CI state
