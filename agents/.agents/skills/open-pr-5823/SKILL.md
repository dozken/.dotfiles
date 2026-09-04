---
name: open-pr-5823
description: Open the PR for issue #5823 (Python editor autocomplete fix). Branch fix-5823-python-autocomplete is already pushed and the demo video is already uploaded to GitHub; this just creates the PR against develop with the prepared body. Run in any session, incl. a claude.ai scheduled task.
---

# open-pr-5823

Everything machine-bound is already done: branch `fix-5823-python-autocomplete` is pushed to `origin`, and the demo mp4 is uploaded to GitHub user-attachments. This skill only opens the PR — a pure GitHub-API call, so it works from any machine or a claude.ai cloud scheduled task (needs GitHub write access via `gh` auth or a GitHub connector).

## Preconditions

- GitHub write access to `Presight-AI/vantage-frontend` (a `gh`-authed session, or GitHub MCP/connector).
- Branch already on remote: `git ls-remote --heads origin fix-5823-python-autocomplete` returns a ref. (If empty, the branch was never pushed — stop and tell the user; the local worktree is needed to push it.)

## Do

1. Idempotency — bail if the PR already exists:
   ```bash
   gh pr list --repo Presight-AI/vantage-frontend --head fix-5823-python-autocomplete --state all --json url,state
   ```
   If a row exists, print its URL and stop — do NOT open a duplicate.

2. Open the PR against `develop`. The body is `pr-body.md` next to this SKILL.md (it embeds the demo video as a bare user-attachments URL, which GitHub renders as an inline player):
   ```bash
   gh pr create \
     --repo Presight-AI/vantage-frontend \
     --base develop \
     --head fix-5823-python-autocomplete \
     --title "fix(code-editor): restore Python DM/pyworker autocomplete alongside variables (#5823)" \
     --body-file "$(dirname "$0")/pr-body.md"
   ```
   In a cloud session where this file isn't on disk, paste the body inline instead (the full text lives in `pr-body.md`). The demo video URL is:
   `https://github.com/user-attachments/assets/ce465b09-bdd9-4870-8bc8-e8969e9b7812`

3. Report the PR URL and confirm the video rendered inline (open the PR page; a `<video>` player should appear under "## Demo").

## Rules

- Do NOT open a duplicate PR — always run the idempotency check first.
- No blame on which PR introduced the regression beyond the mechanism described in the body.
- No `Co-Authored-By: Claude` trailer anywhere.
- The video embeds ONLY as a bare URL on its own line — never wrap it in `![]()` (that renders a broken image, not a player).
