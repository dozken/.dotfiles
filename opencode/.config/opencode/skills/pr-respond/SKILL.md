---
name: pr-respond
description: address human PR review comments, apply, reply, resolve, push. Use when user says address review, respond to comments, handle reviewer feedback, apply PR suggestions, or reviewer left comments. Human-review twin of review-loop.
---

# PR Respond

Close the *human* review loop the way review-loop closes the AI one: fetch reviewer threads, apply, reply, resolve, push.

Use `todowrite` early. One todo per unresolved thread.

## Gather threads

1. `gh pr view --json number,title,reviewDecision`.
2. Pull review comments with file/line/thread:
   - `gh api repos/{owner}/{repo}/pulls/<num>/comments --paginate` (inline threads), and
   - `gh pr view <num> --comments` (top-level review summaries).
3. Filter to **unresolved** threads only. Group by file.

## Per thread

- Read the comment + the referenced code before editing.
- Classify:
  - **Actionable** — make the minimal change requested.
  - **Question** — answer in a reply, no code change.
  - **Disagree** — reply with reasoning, do not silently ignore; ask user if it's a judgment call.
- Keep each fix scoped to that thread. Never bundle unrelated edits.

## Reply + resolve

- After fixing, reply on the thread referencing what changed (short).
  - `gh api repos/{owner}/{repo}/pulls/<num>/comments/<id>/replies -f body="..."`
- Resolve threads you addressed (GraphQL `resolveReviewThread`, or note them for the user if API access is limited).
- Leave unresolved only threads needing the user's decision — list them.

## Ship

- Commit repo-style message (e.g. `review: address feedback`), push.
- If review requested re-review: `gh pr edit --add-reviewer <login>` or comment `@reviewer ready`.
- `gh pr checks --watch`.

## Output

- threads found / addressed / left for user (with reasons)
- files changed
- replies posted, threads resolved
- push + CI state
