---
name: ip
description: Send investigation prompts for GitHub issues into opencode tmux windows via the `ip` CLI. Use when the user asks to dispatch, queue, or send issue investigation prompts to local issue worktrees.
---

# IP

Use local CLI `ip` to dispatch investigation prompts into opencode tmux windows for issue worktrees.

## When to Use

Use this skill when user wants to:

- Send investigation prompt for one issue
- Send prompts for default issue list
- Target exact feature branch worktree
- Dry-run issue dispatch before touching tmux or git

## Command

```bash
ip [--issue=<number>] [--dry-run] [feature-<issue>-<slug>]
```

## Examples

Single issue by number:

```bash
ip --issue=2346
```

Dry run:

```bash
ip --dry-run --issue=2346
```

Exact branch target:

```bash
ip feature-2346-query
```

Default issue batch:

```bash
ip
```

## What It Does

For each selected issue:

1. Resolve branch/worktree
2. Ensure worktree clean
3. Rebase on `origin/develop`
4. Reuse or create tmux window in session `vantage-frontend`
5. Start `opencode` if needed
6. Paste prompt:

```text
Issue #<n>
Run: gh issue view <n> --comments
Then investigate and propose implementation plan.
Do not implement yet. Confirm plan and wait for instructions.
```

## Notes

- CLI path: `~/.dotfiles/scripts/ip`
- Source: `~/.dotfiles/scripts/dispatch-issue-investigations.ts`
- Uses worktrees under `~/work/vantage-frontend.<branch>`
- Uses tmux session `vantage-frontend`
- Exact branch arg skips some branch discovery work
