# Gemini Agent

Gemini CLI follows the same hive pattern as Claude — different file name, same idea.

## How it hooks into the hive

Gemini CLI loads `~/.gemini/GEMINI.md` (or `GEMINI.md` in the project root, depending
on version) as its global instructions.

> **Check your version first:** Run `gemini --help` or check the Gemini CLI docs to
> confirm the exact config file path before symlinking.

**Option A — Share Claude's CLAUDE.md (simplest):**
If your Gemini and Claude instructions are identical, just symlink to the same file:
```bash
mkdir -p ~/.gemini
ln -sf ~/hive/machines/<your-machine>/CLAUDE.md ~/.gemini/GEMINI.md
```

**Option B — Separate GEMINI.md (if Gemini needs different instructions):**
Add a `GEMINI.md` source file alongside `machine.md` and extend `propagate.sh`
to build a `GEMINI.md` artifact the same way it builds `CLAUDE.md`. Then symlink:
```bash
mkdir -p ~/.gemini
ln -sf ~/hive/machines/<your-machine>/GEMINI.md ~/.gemini/GEMINI.md
```

## Shared memory

Gemini reads the same `memory/` files as Claude. Update them the same way at session end
and run `scripts/sync.sh`. Both agents stay current across all machines.

## Handoffs

Gemini participates in the cross-agent handoff protocol in `handoffs/`.
On session start, scan root `handoffs/` for open handoffs addressed to gemini.
Respond, set status to resolved, move to `handoffs/archive/`, sync.

See `handoffs/README.md` for the full protocol.

## Notes
- Agents don't modify each other's config files
- The shared rules in `CLAUDE-shared.md` apply to Gemini too — same preferences,
  same session protocol, same memory update discipline
- If using Option B, keep the `propagate.sh` build logic consistent with Claude's
