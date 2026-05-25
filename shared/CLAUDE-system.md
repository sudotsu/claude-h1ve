# H1VE System Instructions

h1ve infrastructure rules — session protocol, build rules, operational rules, and machine context shared across all machines. Never edit machines/<name>/CLAUDE.md directly; edit here and run propagate.sh.

<!-- BEGIN SHARED -->

## H1VE Context
- N machines: [list your machines here — e.g., "dev laptop", "home desktop", "work machine"]
- Interests: [your domains and areas of focus]
- Comfortable with [your technical background]

## Primary Tech Stack
- **[Primary language]** — e.g., TypeScript, Python, Go
- **[Primary framework]** — e.g., Next.js, FastAPI, Express
- **[Styling/CSS]** — e.g., Tailwind CSS, CSS Modules
- **Bash / Shell** — tooling, sync scripts, hooks

**Version rule**: Never assume or hard-code version numbers for any library or runtime. Either check `package.json` / official docs, or ask for confirmation before writing version-specific code.

## H1VE Session Protocol
**On session start** (do this before responding to the user's first message, regardless of what they asked):
1. `git pull` is automatic — a `SessionStart` hook runs `scripts/session-start.sh` which pulls the repo at session begin (matched on `startup|resume|clear` subtypes). You do not need to pull manually.
2. Check what changed across machines: `cd ~/h1ve && git log --oneline -10` and `git diff HEAD~3 -- memory/`
3. Auto-memory (`~/h1ve/memory/claude/MEMORY.md`) is loaded automatically at session start — no need to read it manually. It contains cross-machine learnings written by Claude instances on all machines.
4. Check the **root** `~/h1ve/handoffs/` directory (do NOT read `handoffs/archive/`) for any open handoffs addressed to claude — surface them to the user immediately
5. Briefly tell the user what's new from other machines — or confirm you're current if nothing changed

**On session end:** Auto-memory handles cross-session learning automatically — preferences, project state, decisions, and patterns are written without manual effort. Only one manual task remains:
- `memory/kb.md` — high-signal technical gotchas only: tool quirks, system behaviors, hard-won fixes that would bite you again. Edit in-place, update superseded entries, never just append. High bar — if it wouldn't recur, skip it.

**Sync is automatic** — a `SessionEnd` hook runs `~/h1ve/scripts/sync.sh` when the session ends, and a `PreCompact` hook runs it before any context compaction (manual or auto). No manual sync needed. If you need to sync mid-session for any other reason, run it manually: `bash ~/h1ve/scripts/sync.sh`

## H1VE Operational Rules

**Scratchpad rule:** All temporary files, test scripts, raw API responses, or credential-bearing output MUST be created inside `~/h1ve/scratch/`. Never write throwaway files to the repo root or any tracked directory. `scratch/` is gitignored — nothing inside it will be auto-synced.

**Draft rule:** When authoring a net-new file (especially in `handoffs/`), you MUST write to `<filename>.md.draft` first. Only rename to `<filename>.md` when the file is 100% structurally complete and ready for execution. `*.draft` files are gitignored — a crash mid-write leaves broken state safely untracked on the local machine only.

## H1VE Build Rules

**machines/<name>/CLAUDE.md is a generated build artifact — never edit it directly.**
- To update machine specs, paths, or tools: edit `machines/<name>/machine.md`
- To update h1ve system rules: edit `shared/CLAUDE-system.md`
- To update behavior rules: edit `shared/CLAUDE-behavior.md`
- Run `scripts/propagate.sh` to rebuild (or let `sync.sh` do it automatically on session end)
- The warning banner at line 1 of each CLAUDE.md is there for exactly this reason
