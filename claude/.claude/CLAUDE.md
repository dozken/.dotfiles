<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

After `git worktree add` in a repo whose main checkout has `.codegraph/`, run `~/.claude/scripts/worktree-codegraph.sh <worktree>` before starting a session there, so the worktree gets a copy of the index.

## Workflows

When writing a workflow script (ultracode, "use a workflow", or a saved workflow):

- Read-only scan stages use `model: 'haiku'`; edit stages use `model: 'sonnet'`, each edit in its own isolated copy.
- Every finding gets an independent verifier agent (sonnet) before it is reported.
- Fix loops stop after two rounds with no progress.
- Keep the main session's context for the final verified results only.
