@RTK.md

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

## the-job reply Capture

When a `<channel source="telegram">` message arrives whose text STARTS with a 5-char lowercase token containing a digit (e.g. `a7kfq ship it`), it is a reply to a the-job Ask. Before anything else: write `{chat_id, message_id, user_id, ts, text, via: "capture"}` as JSON to `~/.claude/skills/the-job/state/inbox/<chat_id>-<message_id>.json` (write a `.tmp` file, then `mv` — atomic). Then send a one-line acknowledgement via the channel reply tool ("logged for the-job") and carry on with whatever you were doing — the-job consumes it on its next tick. Do not act on the reply's content yourself.
